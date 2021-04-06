defmodule <%= inspect context.module_name %> do
  # NOTICE: This module is generated from the corresponding mix task command to the OpenAPI Specification
  # in the first time running, and then it WON'T be modified in the ongoing generation command(s)
  # once this file exists, please write the crypto-related configuration to the bearer token in this module.
  @behaviour Oasis.Token

  @impl true
  def crypto_config(conn, opts) do
    # %Oasis.Token.Crypto{
    #   secret_key_base: ""
    # }
  end

end
