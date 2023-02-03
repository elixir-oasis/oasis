defmodule Oasis.HMACTokenTest do
  use ExUnit.Case
  use Plug.Test

  import Oasis.HMACToken
  import Oasis.Test.Support.HMAC

  describe "sign" do
    test "sign success - host only" do
      c = case_host_only()

      conn = conn(:get, c.path_and_query)
      conn = %Plug.Conn{conn | host: c.host}

      assert sign(conn, c.signed_headers, c.secret, :sha256) == c.signature_sha256
      assert sign(conn, c.signed_headers, c.secret, :sha512) == c.signature_sha512
      assert sign(conn, c.signed_headers, c.secret, :md5) == c.signature_md5
    end

    test "sign success - with date" do
      c = case_with_date()

      conn = 
        conn(:get, c.path_and_query)
        |> put_req_header("x-oasis-date", c.x_oasis_date)

      conn = %Plug.Conn{conn | host: c.host}

      assert sign(conn, c.signed_headers, c.secret, :sha256) == c.signature_sha256
    end

    test "sign failed - with date and miss host" do
      c = case_with_date()

      conn =
        conn(:get, c.path_and_query)
        # miss host
        |> put_req_header("x-oasis-date", c.x_oasis_date)

      assert sign(conn, c.signed_headers, c.secret, :sha256) != c.signature_sha256
    end
  end

  describe "verify" do
    test "verify signature failed" do
      c = case_host_only()

      conn = conn(:get, c.path_and_query)
      conn = %Plug.Conn{conn | host: c.host}

      token = %{
        credential: c.credential,
        signed_headers: c.signed_headers,
        signature: "wrong signature"
      }

      opts = [
        algorithm: :sha256,
        security: Oasis.Gen.HMACAuthHostOnly,
        signed_headers: c.signed_headers
      ]

      assert {:error, :invalid_token} = verify(conn, token, opts)
    end

    test "verify signature success - host only" do
      c = case_host_only()

      conn = conn(:get, c.path_and_query)
      conn = %Plug.Conn{conn | host: c.host}

      token = %{
        credential: c.credential,
        signed_headers: c.signed_headers,
        signature: c.signature_sha256
      }

      opts = [
        algorithm: :sha256,
        security: Oasis.Gen.HMACAuthHostOnly,
        signed_headers: c.signed_headers
      ]

      assert {:ok, _} = verify(conn, token, opts)
    end

    test "verify signature success - with date" do
      c = case_with_date()

      conn =
        conn(:get, c.path_and_query)
        |> put_req_header("x-oasis-date", c.x_oasis_date)

      conn = %Plug.Conn{conn | host: c.host}

      token = %{
        credential: c.credential,
        signed_headers: c.signed_headers,
        signature: c.signature_sha256
      }

      opts = [
        algorithm: :sha256,
        security: Oasis.Gen.HMACAuthHostOnly,
        signed_headers: c.signed_headers
      ]

      assert {:ok, _} = verify(conn, token, opts)
    end

    test "verify signature success - with body" do
      c = case_with_body()

      conn =
        conn(:post, c.path_and_query)
        |> put_req_header("x-oasis-body-sha256", c.x_oasis_body_sha256)

      conn = %Plug.Conn{conn | host: c.host}

      token = %{
        credential: c.credential,
        signed_headers: c.signed_headers,
        signature: c.signature_sha256
      }

      opts = [
        algorithm: :sha256,
        security: Oasis.Gen.HMACAuthHostOnly,
        signed_headers: c.signed_headers
      ]

      assert {:ok, _} = verify(conn, token, opts)
    end
  end
end
