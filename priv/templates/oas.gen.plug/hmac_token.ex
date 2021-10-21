defmodule <%= inspect context.module_name %> do
  # NOTICE: This module is generated when run `mix oas.gen.plug` task command with the OpenAPI Specification file
  # in the first time, and then it WILL NOT be modified in the future generation command(s) once this file exists,
  # please write the crypto-related configuration to the bearer token in this module.
  @behaviour Oasis.HMACToken
  alias Oasis.HMACToken.Crypto

  @impl true
  def crypto_config(_conn, _opts, _credential) do
    # %Crypto{
    #   credential: "...",
    #   secret: "..."
    # }
    nil
  end

  @impl true
  def verify(conn, token, opts) do
    with {:ok, _} <- Oasis.HMACToken.verify(conn, token, opts) do
      # {:error, :expired}
      # {:error, :invalid_token}
      {:ok, token}
    end
  end

end