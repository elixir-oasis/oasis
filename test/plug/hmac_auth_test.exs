defmodule Oasis.Plug.HmacAuthTest do
  use ExUnit.Case, asysnc: false
  use Plug.Test

  alias Plug.Conn

  import Oasis.Plug.HmacAuth

  defmodule HmacAuth do
    @behaviour Oasis.HmacToken

    alias Oasis.HmacToken.Crypto

    @impl true
    def crypto_configs(%Conn{}, opts) do
      [
        %Crypto{
          credential: "test_client",
          secret: "secret",
          max_age: 1500
        }
      ]
    end

    @impl true
    def verify(conn, token, opts) do
      conn
      |> IO.inspect()
    end
  end

  @path_and_query "/test?a=b"
  @host "localhost:4000"
  @signed_headers "host"
  @credential "test_client"
  @signature "aqg8DKRSwWhFQq9lr/TwTL//3F3p72bBpDSIfjqYoms="

  test "missing required :security option" do
    assert_raise RuntimeError,
                 ~r|no :security option found in path /test with plug Oasis.Plug.HmacAuth|,
                 fn ->
                   conn(:get, @path_and_query)
                   |> hmac_auth()
                 end
  end

  test "invalid token" do
    assert_raise Oasis.BadRequestError,
                 ~r|the hmac token is invalid|,
                 fn ->
                   conn(:get, @path_and_query)
                   |> put_req_header("host", @host)
                   |> put_req_header(
                     "authorization",
                     "HMAC-SHA256 Credential=#{@credential}&SignedHeaders=#{@signed_headers}&Signature=wrong"
                   )
                   |> hmac_auth(security: HmacAuth, signed_headers: @signed_headers)
                 end
  end

  test "invalid credential" do
    assert_raise Oasis.BadRequestError,
                 ~r|the credential in the authorization header is not assigned|,
                 fn ->
                   conn(:get, @path_and_query)
                   |> put_req_header("host", @host)
                   |> put_req_header(
                     "authorization",
                     "HMAC-SHA256 Credential=client_not_exist&SignedHeaders=#{@signed_headers}&Signature=#{@signature}"
                   )
                   |> hmac_auth(security: HmacAuth, signed_headers: @signed_headers)
                 end
  end

  test "verify success" do
    conn(:get, @path_and_query)
    |> put_req_header("host", @host)
    |> put_req_header(
      "authorization",
      "HMAC-SHA256 Credential=#{@credential}&SignedHeaders=#{@signed_headers}&Signature=#{@signature}"
    )
    |> hmac_auth(security: HmacAuth, signed_headers: @signed_headers)
  end
end
