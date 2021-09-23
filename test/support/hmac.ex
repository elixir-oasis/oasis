defmodule Oasis.Test.Support.Hmac do
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
      x_oasis_date: "Wed, 15 Sep 2021 06:41:35 GMT",
      signed_headers: "host;x-oasis-date",
      signature_sha256: "UrEyRzhGrsNm2PdIDQV89wdVTCJlP8flshTxs3hO4vw="
    }
  end

  def case_with_body() do
    %{
      credential: "test_client",
      secret: "secret",
      path_and_query: "/test_hmac_with_body",
      host: "localhost:4000",
      body: "{\"a\": \"b\"}",
      x_oasis_body_sha256: "3P5+6CXpXgFhLem7XGgE59ZNsvVA4DSuMwTRtYv2FTM=",
      signed_headers: "host;x-oasis-body-sha256",
      signature_sha256: "FE2ny2hYuP/02bSxOv3YjZnYJbgn/ZNUuE6ZwJ9p/6Q="
    }
  end

  def read_body(conn) do
    case Plug.Conn.read_body(conn, length: 1_000_000_000_000) do
      {:ok, body, _} -> {:ok, body}
      _ -> {:error, :read_body_error}
    end
  end

  def get_header(conn, key) do
    conn
    |> Plug.Conn.get_req_header(key)
    |> case do
      [date] -> date
      _ -> nil
    end
  end

  def hmac(subtype, secret, content) do
    Base.encode64(:crypto.mac(:hmac, subtype, secret, content))
  end
end

defmodule Oasis.Test.Support.Hmac.TokenHostOnly do
  @behaviour Oasis.HmacToken

  alias Oasis.HmacToken.Crypto
  import Oasis.Test.Support.Hmac

  @impl true
  def crypto_configs(_conn, _opts) do
    c = case_host_only()

    [
      %Crypto{
        credential: c.credential,
        secret: c.secret
      }
    ]
  end
end

defmodule Oasis.Test.Support.Hmac.TokenWithDate do
  @behaviour Oasis.HmacToken

  alias Oasis.HmacToken.Crypto
  import Oasis.Test.Support.Hmac

  @impl true
  def crypto_configs(_conn, _opts) do
    c = case_host_only()

    [
      %Crypto{
        credential: c.credential,
        secret: c.secret
      }
    ]
  end

  @impl true
  def verify(conn, token, opts) do
    with {:ok, _} <- Oasis.HmacToken.verify_signature(conn, token, opts) do
      # actual:
      # parse & verify date
      # could not before (now - max_age)
      {:error, :expired}
    end
  end
end

defmodule Oasis.Test.Support.Hmac.TokenWithBody do
  @behaviour Oasis.HmacToken

  alias Oasis.HmacToken.Crypto
  import Oasis.Test.Support.Hmac

  @impl true
  def crypto_configs(_conn, _opts) do
    c = case_host_only()

    [
      %Crypto{
        credential: c.credential,
        secret: c.secret
      }
    ]
  end

  @impl true
  def verify(conn, token, opts) do
    with {:ok, _} <- Oasis.HmacToken.verify_signature(conn, token, opts),
         {:ok, raw_body} <- Oasis.Test.Support.Hmac.read_body(conn) do
      scheme = opts[:scheme] |> String.trim_leading("hmac-") |> String.to_atom()

      crypto =
        crypto_configs(conn, opts)
        |> Enum.find(&(&1.credential == token.credential))

      body_hmac = Oasis.Test.Support.Hmac.hmac(scheme, crypto.secret, raw_body)
      body_hmac_header = Oasis.Test.Support.Hmac.get_header(conn, "x-oasis-body-sha256")

      if body_hmac == body_hmac_header do
        {:ok, token}
      else
        {:error, :invalid}
      end
    end
  end
end
