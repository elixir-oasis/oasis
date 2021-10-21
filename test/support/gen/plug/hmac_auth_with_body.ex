defmodule Oasis.Gen.HMACAuthWithBody do
  # NOTICE: This module is generated when run `mix oas.gen.plug` task command with the OpenAPI Specification file
  # in the first time, and then it WILL NOT be modified in the future generation command(s) once this file exists,
  # please write the crypto-related configuration to the bearer token in this module.
  @behaviour Oasis.HMACToken
  alias Oasis.HMACToken.Crypto
  import Oasis.Test.Support.HMAC

  @impl true
  def crypto_config(_conn, _opts, credential) do
    c = case_with_body()

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
      algorithm = opts[:algorithm]
      raw_body = conn.assigns.raw_body

      crypto = crypto_config(conn, opts, token.credential)

      body_hmac = hmac(algorithm, crypto.secret, raw_body)

      body_hmac_header = get_header(conn, "x-oasis-body-sha256")

      if body_hmac == body_hmac_header do
        {:ok, token}
      else
        {:error, :invalid_token}
      end
    end
  end

  defp get_header(conn, key) do
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
