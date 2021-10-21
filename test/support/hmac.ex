defmodule Oasis.Test.Support.HMAC do
  def case_host_only() do
    %{
      credential: "test_client",
      secret: "secret",
      path_and_query: "/test_hmac_host_only?a=b",
      host: "localhost:4000",
      signed_headers: "host",
      signature_sha256: "XOZxCY4ccTBtHmMDoyURR2SO+cRUV4ZvmxGD0KAdpmU=",
      signature_sha512:
        "xlZmPwrZ8IBSl9aPpKN2aScaDvpdl2XkFR34rGWIXTstHCJW05CtZk/N8aAFX7QHqiKSAj50FPrQZyAUVKa/4g==",
      signature_md5: "sMujcUnCkq86wbGpyZ63Pg=="
    }
  end

  def case_with_date() do
    %{
      credential: "test_client",
      secret: "secret",
      path_and_query: "/test_hmac_with_date?a=b",
      host: "localhost:4000",
      x_oasis_date: "2021-09-15T06:41:35+00:00",
      signed_headers: "host;x-oasis-date",
      signature_sha256: "oUicQj78yrLUm/7VtMOXvIp81eIj4hubSPCYX5tFzMU="
    }
  end

  def case_with_date_now() do
    now = DateTime.utc_now()

    c = %{
      credential: "test_client",
      secret: "secret",
      path_and_query: "/test_hmac_with_date?a=b",
      host: "localhost:4000",
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
      host: "localhost:4000",
      body: "{\"a\": \"b\"}",
      content_type: "application/json",
      x_oasis_body_sha256: "3P5+6CXpXgFhLem7XGgE59ZNsvVA4DSuMwTRtYv2FTM=",
      signed_headers: "host;x-oasis-body-sha256",
      signature_sha256: "FE2ny2hYuP/02bSxOv3YjZnYJbgn/ZNUuE6ZwJ9p/6Q="
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
