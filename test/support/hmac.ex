defmodule Oasis.Test.Support.HMAC do
  def case_host_only() do
    %{
      credential: "test_client",
      secret: "secret",
      path_and_query: "/test_hmac_host_only?a=b",
      host: "localhost",
      port: 4000,
      signed_headers: "host",
      signature_sha256: "NA6oAtt+2G4ckGHuCTHirkirkCeLZE497SCR5Hz8byc=",
      signature_sha512:
        "XRZmh65tktr7LZWAdScEMMSQTf0nfwm23GCI2wR6ijenq4ZRRUfONSEZAeNcuhKtvjOwtNzkgZWOXGCEA5kNvQ==",
      signature_md5: "/q5xnWpFvqVMxOjkIb25aQ=="
    }
  end

  def case_with_date() do
    %{
      credential: "test_client",
      secret: "secret",
      path_and_query: "/test_hmac_with_date?a=b",
      host: "localhost",
      port: 4002,
      x_oasis_date: "2021-09-15T06:41:35+00:00",
      signed_headers: "host;x-oasis-date",
      signature_sha256: "tILVsjYOPLqMmkKTsPldFg41DcHshZ7EojKFe450vGA="
    }
  end

  def case_with_date_now() do
    now = DateTime.utc_now()

    c = %{
      credential: "test_client",
      secret: "secret",
      path_and_query: "/test_hmac_with_date?a=b",
      host: "localhost",
      port: 4002,
      x_oasis_date: DateTime.to_iso8601(now),
      signed_headers: "host;x-oasis-date",
      signature_sha256: ""
    }

    string_to_sign = "GET\n#{c.path_and_query}\n#{c.host};#{c.x_oasis_date}"
    signature_sha256 = Base.encode64(:crypto.mac(:hmac, :sha256, c.secret, string_to_sign))
    %{c | signature_sha256: signature_sha256}
  end

  def case_with_body() do
    %{
      credential: "test_client",
      secret: "secret",
      path_and_query: "/test_hmac_with_body",
      host: "localhost",
      port: 4002,
      body: "{\"a\": \"b\"}",
      content_type: "application/json",
      x_oasis_body_sha256: "3P5+6CXpXgFhLem7XGgE59ZNsvVA4DSuMwTRtYv2FTM=",
      signed_headers: "host;x-oasis-body-sha256",
      signature_sha256: "m8O7D9VfeEzPwXjvqUaEw2fRmunQOZLOo3n5YxmtS9M=",
    }
  end
end

defmodule Oasis.Test.Support.HMAC.TokenVerifyReturnUnknown do
  @behaviour Oasis.HMACToken

  alias Oasis.HMACToken.Crypto
  import Oasis.Test.Support.HMAC

  @impl true
  def crypto_config(_conn, _opts, credential) do
    c = case_host_only()

    if c.credential == credential do
      %Crypto{
        credential: c.credential,
        secret: c.secret
      }
    else
      nil
    end
  end

  @impl true
  def verify(conn, token, opts) do
    with {:ok, _} <- Oasis.HMACToken.verify(conn, token, opts) do
      {:error, :unknown_error}
    end
  end
end
