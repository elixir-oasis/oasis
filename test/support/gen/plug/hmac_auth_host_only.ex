defmodule Oasis.Gen.HMACAuthHostOnly do
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
      # {:error, :expired}
      # {:error, :invalid}
      {:ok, token}
    end
  end
end
