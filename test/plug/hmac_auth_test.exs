defmodule Oasis.Plug.HmacAuthTest do
  use ExUnit.Case, asysnc: false
  use Plug.Test

  alias Plug.Conn

  import Oasis.Plug.HmacAuth

  defmodule HmacAuth do
    @behaviour Oasis.HmacToken

    alias Oasis.HmacToken.Crypto

    @impl true
    def crypto_configs(%Conn{}, _opts) do
      [
        %Crypto{
          credential: "test_client",
          secret: "secret"
        }
      ]
    end

    @impl true
    def verify(conn, _token, _opts) do
      {:ok, conn}
    end
  end

  defmodule HmacAuthWithDateValidation do
    @behaviour Oasis.HmacToken

    alias Oasis.HmacToken.Crypto

    @impl true
    def crypto_configs(%Conn{}, _opts) do
      [
        %Crypto{
          credential: "test_client",
          secret: "secret"
        }
      ]
    end

    @impl true
    def verify(_conn, _token, _opts) do
      # actual:
      # parse & verify date
      # could not before (now - max_age)
      {:error, :expired}
    end
  end

  @path_and_query "/test?a=b"
  @host "localhost:4000"
  @signed_headers "host"
  @credential "test_client"
  @signature "aqg8DKRSwWhFQq9lr/TwTL//3F3p72bBpDSIfjqYoms="

  @signed_headers_with_date "host;x-oasis-date"

  describe "parse_hmac_auth" do
    test "parse fail with wrong fields" do
      conn =
        conn(:get, "/")
        |> put_req_header(
          "authorization",
          "HMAC-SHA256 Credential1=credential&SignedHeaders=signed_headers&Signature=signature"
        )

      assert {:error, _} = parse_hmac_auth(conn, "hmac-sha256")
    end

    test "parse fail with wrong scheme" do
      conn =
        conn(:get, "/")
        |> put_req_header(
          "authorization",
          "HMAC-SHA Credential=credential&SignedHeaders=signed_headers&Signature=signature"
        )

      assert {:error, _} = parse_hmac_auth(conn, "hmac-sha256")
    end

    test "parse success" do
      conn =
        conn(:get, "/")
        |> put_req_header(
          "authorization",
          "HMAC-SHA256 hello=world&Credential=#{@credential}&SignedHeaders=#{@signed_headers}&Signature=wrong"
        )

      assert {:ok, token} = parse_hmac_auth(conn, "hmac-sha256")
      # extra keys will be ignored
      assert token |> Map.keys() |> length == 3
    end
  end

  describe "hmac_auth" do
    test "missing required :security option" do
      assert_raise RuntimeError,
                   ~r|no :security option found in path / with plug Oasis.Plug.HmacAuth|,
                   fn ->
                     conn(:get, "/")
                     |> put_req_header("host", @host)
                     |> put_req_header(
                       "authorization",
                       "HMAC-SHA256 Credential=#{@credential}&SignedHeaders=#{@signed_headers}&Signature=#{@signature}"
                     )
                     |> hmac_auth(scheme: "hmac-sha256", signed_headers: @signed_headers)
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
                     |> hmac_auth(
                       scheme: "hmac-sha256",
                       security: HmacAuth,
                       signed_headers: @signed_headers
                     )
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
                     |> hmac_auth(
                       scheme: "hmac-sha256",
                       security: HmacAuth,
                       signed_headers: @signed_headers
                     )
                   end
    end

    test "verify success" do
      conn =
        conn(:get, @path_and_query)
        |> put_req_header("host", @host)
        |> put_req_header(
          "authorization",
          "HMAC-SHA256 Credential=#{@credential}&SignedHeaders=#{@signed_headers}&Signature=#{@signature}"
        )

      assert hmac_auth(conn,
               scheme: "hmac-sha256",
               security: HmacAuth,
               signed_headers: @signed_headers
             )
    end

    test "verify expired" do
      assert_raise Oasis.BadRequestError,
                   ~r|the hmac token is expired|,
                   fn ->
                     conn(:get, @path_and_query)
                     |> put_req_header("host", @host)
                     |> put_req_header("x-oasis-date", "Wed, 15 Sep 2021 06:41:35 GMT")
                     |> put_req_header(
                       "authorization",
                       "HMAC-SHA256 Credential=#{@credential}&SignedHeaders=#{@signed_headers_with_date}&Signature=1xRhjH97JJ2r/17XlIxtGv1N4XNf5t8Qu8UN94xmlpM="
                     )
                     |> hmac_auth(
                       scheme: "hmac-sha256",
                       security: HmacAuthWithDateValidation,
                       signed_headers: @signed_headers_with_date
                     )
                   end
    end
  end
end
