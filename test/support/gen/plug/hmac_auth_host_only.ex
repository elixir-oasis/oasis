defmodule Oasis.Gen.HmacAuthHostOnly do
  # NOTICE: This module is generated when run `mix oas.gen.plug` task command with the OpenAPI Specification file
  # in the first time, and then it WILL NOT be modified in the future generation command(s) once this file exists,
  # please write the crypto-related configuration to the bearer token in this module.
  @behaviour Oasis.HmacToken
  alias Oasis.HmacToken.Crypto

  @impl true
  def crypto_configs(_conn, _opts) do
    [
      %Crypto{
        credential: "test_client",
        secret: "secret"
      }
    ]
  end

  @impl true
  def verify(conn, token, opts) do
    with {:ok, _} <- Oasis.HmacToken.verify_signature(conn, token, opts) do
      # {:error, :expired}
      # {:error, :invalid}
      {:ok, token}
    end
  end
end