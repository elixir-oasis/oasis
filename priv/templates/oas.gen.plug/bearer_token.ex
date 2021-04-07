defmodule <%= inspect context.module_name %> do
  # NOTICE: This module is generated when run `mix oas.gen.plug` task command with the OpenAPI Specification file
  # in the first time, and then it WILL NOT be modified in the future generation command(s) once this file exists,
  # please write the crypto-related configuration to the bearer token in this module.
  @behaviour Oasis.Token

  @impl true
  def crypto_config(_conn, _opts) do
    # %Oasis.Token.Crypto{
    #   secret_key_base: ""
    # }
  end

end
