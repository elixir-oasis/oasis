defmodule Oasis.Plug.HmacAuthTest do
  use ExUnit.Case
  use Plug.Test

  import Oasis.Plug.HmacAuth
  import Oasis.Test.Support.Hmac

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
          "HMAC-SHA256 hello=world&Credential=credential#&SignedHeaders=signed_headers&Signature=signature"
        )

      assert {:ok, token} = parse_hmac_auth(conn, "hmac-sha256")
      # extra keys will be ignored
      assert token |> Map.keys() |> length == 3
    end
  end

  describe "hmac_auth" do
    test "missing required :scheme option" do
      c = case_host_only()

      conn =
        conn(:get, "/")
        |> put_req_header("host", c.host)
        |> put_req_header(
          "authorization",
          "HMAC-SHA256 Credential=#{c.credential}&SignedHeaders=#{c.signed_headers}&Signature=#{c.signature_sha256}"
        )

      assert_raise RuntimeError,
                   ~r|no :scheme option found in path / with plug Oasis.Plug.HmacAuth|,
                   fn ->
                     hmac_auth(conn,
                       signed_headers: c.signed_headers,
                       security: Oasis.Test.Support.Hmac.TokenHostOnly
                     )
                   end
    end

    test "missing required :security option" do
      c = case_host_only()

      conn =
        conn(:get, "/")
        |> put_req_header("host", c.host)
        |> put_req_header(
          "authorization",
          "HMAC-SHA256 Credential=#{c.credential}&SignedHeaders=#{c.signed_headers}&Signature=#{c.signature_sha256}"
        )

      assert_raise RuntimeError,
                   ~r|no :security option found in path / with plug Oasis.Plug.HmacAuth|,
                   fn ->
                     hmac_auth(conn, scheme: "hmac-sha256", signed_headers: c.signed_headers)
                   end
    end

    test "missing required :signed_headers option" do
      c = case_host_only()

      conn =
        conn(:get, "/")
        |> put_req_header("host", c.host)
        |> put_req_header(
          "authorization",
          "HMAC-SHA256 Credential=#{c.credential}&SignedHeaders=#{c.signed_headers}&Signature=#{c.signature_sha256}"
        )

      assert_raise RuntimeError,
                   ~r|no :signed_headers option found in path / with plug Oasis.Plug.HmacAuth|,
                   fn ->
                     hmac_auth(conn,
                       scheme: "hmac-sha256",
                       security: Oasis.Test.Support.Hmac.TokenHostOnly
                     )
                   end
    end

    test "token missing" do
      c = case_host_only()

      conn =
        conn(:get, c.path_and_query)
        |> put_req_header("host", c.host)

      assert_raise Oasis.BadRequestError,
                   ~r|the hmac token is missing in the authorization header or format is wrong|,
                   fn ->
                     hmac_auth(conn,
                       scheme: "hmac-sha256",
                       security: Oasis.Test.Support.Hmac.TokenHostOnly,
                       signed_headers: c.signed_headers
                     )
                   end
    end

    test "invalid token format" do
      c = case_host_only()

      conn =
        conn(:get, c.path_and_query)
        |> put_req_header("host", c.host)
        |> put_req_header(
          "authorization",
          "HMAC-SHA256 Credential=#{c.credential}&SignedHeadersKeyError=#{c.signed_headers}&Signature=invalid"
        )

      assert_raise Oasis.BadRequestError,
                   ~r|the hmac token is missing in the authorization header or format is wrong|,
                   fn ->
                     hmac_auth(conn,
                       scheme: "hmac-sha256",
                       security: Oasis.Test.Support.Hmac.TokenHostOnly,
                       signed_headers: c.signed_headers
                     )
                   end
    end

    test "invalid token" do
      c = case_host_only()

      conn =
        conn(:get, c.path_and_query)
        |> put_req_header("host", c.host)
        |> put_req_header(
          "authorization",
          "HMAC-SHA256 Credential=#{c.credential}&SignedHeaders=#{c.signed_headers}&Signature=invalid"
        )

      assert_raise Oasis.BadRequestError,
                   ~r|the hmac token is invalid|,
                   fn ->
                     hmac_auth(conn,
                       scheme: "hmac-sha256",
                       security: Oasis.Test.Support.Hmac.TokenHostOnly,
                       signed_headers: c.signed_headers
                     )
                   end
    end

    test "invalid credential" do
      c = case_host_only()

      conn =
        conn(:get, c.path_and_query)
        |> put_req_header("host", c.host)
        |> put_req_header(
          "authorization",
          "HMAC-SHA256 Credential=not_exist&SignedHeaders=#{c.signed_headers}&Signature=#{c.signature_sha256}"
        )

      assert_raise Oasis.BadRequestError,
                   ~r|the credential in the authorization header is not assigned|,
                   fn ->
                     hmac_auth(conn,
                       scheme: "hmac-sha256",
                       security: Oasis.Test.Support.Hmac.TokenHostOnly,
                       signed_headers: c.signed_headers
                     )
                   end
    end

    test "verify success" do
      c = case_host_only()

      conn =
        conn(:get, c.path_and_query)
        |> put_req_header("host", c.host)
        |> put_req_header(
          "authorization",
          "HMAC-SHA256 Credential=#{c.credential}&SignedHeaders=#{c.signed_headers}&Signature=#{c.signature_sha256}"
        )

      assert hmac_auth(conn,
               scheme: "hmac-sha256",
               security: Oasis.Test.Support.Hmac.TokenHostOnly,
               signed_headers: c.signed_headers
             )
    end

    test "verify sha512 success" do
      c = case_host_only()

      conn =
        conn(:get, c.path_and_query)
        |> put_req_header("host", c.host)
        |> put_req_header(
          "authorization",
          "HMAC-SHA512 Credential=#{c.credential}&SignedHeaders=#{c.signed_headers}&Signature=#{c.signature_sha512}"
        )

      assert hmac_auth(conn,
               scheme: "hmac-sha512",
               security: Oasis.Test.Support.Hmac.TokenHostOnly,
               signed_headers: c.signed_headers
             )
    end

    test "verify md5 success" do
      c = case_host_only()

      conn =
        conn(:get, c.path_and_query)
        |> put_req_header("host", c.host)
        |> put_req_header(
          "authorization",
          "HMAC-MD5 Credential=#{c.credential}&SignedHeaders=#{c.signed_headers}&Signature=#{c.signature_md5}"
        )

      assert hmac_auth(conn,
               scheme: "hmac-md5",
               security: Oasis.Test.Support.Hmac.TokenHostOnly,
               signed_headers: c.signed_headers
             )
    end

    test "verify expired" do
      c = case_with_date()

      conn =
        conn(:get, c.path_and_query)
        |> put_req_header("host", c.host)
        |> put_req_header("x-oasis-date", c.x_oasis_date)
        |> put_req_header(
          "authorization",
          "HMAC-SHA256 Credential=#{c.credential}&SignedHeaders=#{c.signed_headers}&Signature=#{c.signature_sha256}"
        )

      assert_raise Oasis.BadRequestError,
                   ~r|the hmac token is expired|,
                   fn ->
                     hmac_auth(conn,
                       scheme: "hmac-sha256",
                       security: Oasis.Test.Support.Hmac.TokenWithDate,
                       signed_headers: c.signed_headers
                     )
                   end
    end
  end
end
