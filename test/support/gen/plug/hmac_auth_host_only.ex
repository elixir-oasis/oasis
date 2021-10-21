defmodule Oasis.Gen.HMACAuthHostOnly do
  # NOTICE: This module is generated when run `mix oas.gen.plug` task command with the OpenAPI Specification file
  # in the first time, and then it WILL NOT be modified in the future generation command(s) once this file exists,
  # please write the crypto-related configuration to the bearer token in this module.
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
end
