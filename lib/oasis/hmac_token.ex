defmodule Oasis.HmacToken do
  @moduledoc """
  """

  defmodule Crypto do
    @moduledoc """
    """

    @enforce_keys [:credential, :secret]

    defstruct [
      :credential,
      :secret
    ]

    @type t :: %__MODULE__{
            credential: String.t(),
            secret: String.t()
          }
  end

  @type opts :: Plug.opts()

  @type verify_error ::
          {:error, :expired}
          | {:error, :invalid}

  @callback crypto_configs(conn :: Plug.Conn.t(), opts :: Keyword.t()) :: [Crypto.t()]

  @callback verify!(conn :: Plug.Conn.t(), Map.t(), opts :: Keyword.t()) :: [Plug.Conn.t()]
end
