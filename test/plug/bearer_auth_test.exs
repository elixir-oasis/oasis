defmodule Oasis.Plug.BearerAuthTest do
  use ExUnit.Case, asysnc: false
  use Plug.Test

  alias Plug.Conn

  import Oasis.Plug.BearerAuth
  import Oasis.Token, only: [sign: 2, random_string: 1]

  defmodule BearerAuth do
    @behaviour Oasis.Token

    alias Oasis.Token.Crypto

    @secret_key_base random_string(64)

    @impl true
    def crypto_config(conn, opts \\ [])
    def crypto_config(%Conn{request_path: "/expired"}, opts) do
      load_crypto_config(opts ++ [max_age: -100])
    end
    def crypto_config(_conn, opts) do
      load_crypto_config(opts)
    end

    defp load_crypto_config(opts) do
      default = [salt: "salt", secret_key_base: @secret_key_base]
      struct(Crypto, default ++ opts)
    end
  end

  defmodule BearerAuthWithVerify do
    @behaviour Oasis.Token

    alias Oasis.Token.Crypto

    @secret_key_base random_string(64)

    @impl true
    def crypto_config(_conn, opts) do
      default = [salt: "salt", secret_key_base: @secret_key_base]
      struct(Crypto, default ++ opts)
    end

    @impl true
    def verify(conn, token, opts) do
      verified = crypto_config(conn, opts) |> Oasis.Token.verify(token)
      case verified do
        {:ok, 1} ->
          verified
        _ ->
          {:error, :invalid}
      end
    end

  end
  
  describe "bearer_auth" do
    test "missing required :security option" do
      id = 123
      crypto = BearerAuth.crypto_config(%Conn{}, [])

      token = sign(crypto, id)

      assert_raise RuntimeError, ~r|no :security option found in path / with plug Oasis.Plug.BearerAuth|, fn ->
        conn(:get, "/")
        |> put_req_header("authorization", "Bearer #{token}")
        |> bearer_auth()
      end
    end

    test "sign and verify a valid token" do
      id = 123
      crypto = BearerAuth.crypto_config(%Conn{}, [])

      token = sign(crypto, id)

      conn =
        conn(:get, "/")
        |> put_req_header("authorization", "Bearer #{token}")
        |> bearer_auth(security: BearerAuth)

      # Since not defined `:key_to_assigns` option, there will not
      # store the verified data into `conn.assigns`
      assert conn.assigns == %{}

      refute conn.status
      refute conn.halted

      # and we can custom it by `:key_to_assigns`
      conn =
        conn(:get, "/")
        |> put_req_header("authorization", "Bearer #{token}")
        |> bearer_auth(security: BearerAuth, key_to_assigns: :id)

      assert conn.assigns.id == id and Map.has_key?(conn.assigns, :verified) == false
    end

    test "raise invalid token error" do
      assert_raise Oasis.BadRequestError, ~r/the bearer token is invalid/, fn ->
        conn(:get, "/")
        |> put_req_header("authorization", "Bearer faketoken")
        |> bearer_auth(security: BearerAuth)
      end
    end

    test "raise expired token error" do
      id = 123

      crypto = BearerAuth.crypto_config(%Conn{}, [])

      token = sign(crypto, id)

      assert_raise Oasis.BadRequestError, ~r/the bearer token is expired/, fn -> 
        conn(:get, "/expired")
        |> put_req_header("authorization", "Bearer #{token}")
        |> bearer_auth(security: BearerAuth)
      end
    end

    test "custom function verify/3" do
      id = 1
      crypto = BearerAuthWithVerify.crypto_config(%Conn{}, [])

      token = sign(crypto, id)

      conn =
        conn(:get, "/")
        |> put_req_header("authorization", "Bearer #{token}")
        |> bearer_auth(security: BearerAuthWithVerify, key_to_assigns: :id)

      assert conn.assigns.id == id

      refute conn.status
      refute conn.halted

      id = 2
      token = sign(crypto, id)

      assert_raise Oasis.BadRequestError, ~r/the bearer token is invalid/, fn ->
        conn(:get, "/")
        |> put_req_header("authorization", "Bearer #{token}")
        |> bearer_auth(security: BearerAuthWithVerify, key_to_assigns: :id)
      end
    end

  end

  describe "parse_bearer_auth" do
    test "returns invalid_request with no authentication header" do
      assert conn(:get, "/")
             |> parse_bearer_auth() == {:error, "invalid_request"}
    end

    test "returns invalid_request with unexpected authentication header" do
      assert conn(:get, "/")
             |> put_req_header("authorization", "Token abcdef")
             |> parse_bearer_auth() == {:error, "invalid_request"}
    end
  end

  describe "request_bearer_auth" do
    test "sets www-authenticate header with realm information" do
      assert conn(:get, "/")
             |> request_bearer_auth()
             |> get_resp_header("www-authenticate") == ["Bearer realm=\"Application\""]

      assert conn(:get, "/")
             |> request_bearer_auth(realm: ~S|"example"|)
             |> get_resp_header("www-authenticate") == ["Bearer realm=\"example\""]
    end

    test "sets www-authenticate header with error information" do
      assert conn(:get, "/")
             |> request_bearer_auth(error: {"invalid_token", "the token expired"})
             |> get_resp_header("www-authenticate") == [
               "Bearer realm=\"Application\",error=\"invalid_token\",error_description=\"the token expired\""
             ]
    end
  end

end
