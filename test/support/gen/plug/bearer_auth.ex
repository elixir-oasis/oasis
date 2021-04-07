defmodule Oasis.Gen.BearerAuth do

  @behaviour Oasis.Token

  alias Oasis.Token.Crypto

  # for test case, as usual it should be configured by environment
  @secret_key_base Oasis.Token.random_string(64)

  @impl true
  def crypto_config(conn, opts \\ []) do
    # for testing proposal to dynamically change `max_age` by request
    max_age = Map.get(conn.params, "max_age")

    default = [salt: "abc"]

    default = if max_age != nil, do: default ++ [{:max_age, max_age}], else: default

    opts = Keyword.merge(default, opts)
    struct(%Crypto{secret_key_base: @secret_key_base}, opts)
  end

end
