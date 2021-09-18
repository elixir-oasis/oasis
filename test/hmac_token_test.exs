defmodule Oasis.HmacTokenTest do
  use ExUnit.Case
  use Plug.Test

  #  alias Plug.Conn
  alias Oasis.HmacToken.Crypto
  import Oasis.HmacToken
  import Oasis.Test.Support.Hmac

  describe "sign!" do
    test "sign success - host only" do
      c = case_host_only()

      crypto = %Crypto{credential: c.credential, secret: c.secret}

      conn =
        conn(:get, c.path_and_query)
        |> put_req_header("host", c.host)

      assert sign!(conn, c.signed_headers, crypto, "hmac-sha256") == c.signature_sha256
      assert sign!(conn, c.signed_headers, crypto, "hmac-sha512") == c.signature_sha512
      assert sign!(conn, c.signed_headers, crypto, "hmac-md5") == c.signature_md5
    end

    test "sign success - with date" do
      c = case_with_date()

      crypto = %Crypto{credential: c.credential, secret: c.secret}

      conn =
        conn(:get, c.path_and_query)
        |> put_req_header("host", c.host)
        |> put_req_header("x-oasis-date", c.x_oasis_date)

      assert sign!(conn, c.signed_headers, crypto, "hmac-sha256") == c.signature_sha256
    end
  end

  describe "verify_signature" do
    test "verify signature failed" do
      c = case_host_only()

      conn =
        conn(:get, c.path_and_query)
        |> put_req_header("host", c.host)

      token = %{
        credential: c.credential,
        signed_headers: c.signed_headers,
        signature: "wrong signature"
      }

      opts = [
        scheme: "hmac-sha256",
        security: Oasis.Test.Support.Hmac.TokenHostOnly,
        signed_headers: c.signed_headers
      ]

      assert {:error, :invalid} = verify_signature(conn, token, opts)
    end

    test "verify signature success - host only" do
      c = case_host_only()

      conn =
        conn(:get, c.path_and_query)
        |> put_req_header("host", c.host)

      token = %{
        credential: c.credential,
        signed_headers: c.signed_headers,
        signature: c.signature_sha256
      }

      opts = [
        scheme: "hmac-sha256",
        security: Oasis.Test.Support.Hmac.TokenHostOnly,
        signed_headers: c.signed_headers
      ]

      assert {:ok, _} = verify_signature(conn, token, opts)
    end

    test "verify signature success - with date" do
      c = case_with_date()

      conn =
        conn(:get, c.path_and_query)
        |> put_req_header("host", c.host)
        |> put_req_header("x-oasis-date", c.x_oasis_date)

      token = %{
        credential: c.credential,
        signed_headers: c.signed_headers,
        signature: c.signature_sha256
      }

      opts = [
        scheme: "hmac-sha256",
        security: Oasis.Test.Support.Hmac.TokenWithDate,
        signed_headers: c.signed_headers
      ]

      assert {:ok, _} = verify_signature(conn, token, opts)
    end
  end
end
