defmodule Oasis.Gen.HMACAuthWithBody do
  # NOTICE: This module is generated when run `mix oas.gen.plug` task command with the OpenAPI Specification file
  # in the first time, and then it WILL NOT be modified in the future generation command(s) once this file exists,
  # please write the crypto-related configuration to the bearer token in this module.
  @behaviour Oasis.HMACToken
  alias Oasis.HMACToken.Crypto

  @impl true
  def crypto_config(_conn, _opts, "test_client") do
    %Crypto{
      credential: "test_client",
      secret: "secret"
    }
  end

  def crypto_config(_conn, _opts, _credential), do: nil

  @impl true
  def verify(conn, token, opts) do
    with {:ok, _} <- Oasis.HMACToken.verify_signature(conn, token, opts) do
      scheme = opts[:scheme] |> String.trim_leading("hmac-") |> String.to_atom()
      raw_body = conn.assigns.raw_body

      crypto = crypto_config(conn, opts, token.credential)

      body_hmac = hmac(scheme, crypto.secret, raw_body)

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
