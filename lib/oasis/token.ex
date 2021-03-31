defmodule Oasis.Token do

  defmodule Crypto do
    @moduledoc """
    A module to 
    """

    defstruct [
      :secret_key_base,
      :secret,
      :salt,
      :key_iterations,
      :key_length,
      :key_digest,
      :signed_at,
      max_age: 7200
    ]

    @type t :: %__MODULE__{
      secret_key_base: String.t(),
      secret: String.t(),
      salt: String.t(),
      key_iterations: pos_integer(),
      key_length: pos_integer(),
      key_digest: atom(),
      signed_at: non_neg_integer(),
      max_age: integer()
    }

  end

  @type opts :: Plug.opts()

  @type verify_error :: {:error, :expired}
                      | {:error, :invalid}

  @callback crypto_config(conn :: Plug.Conn.t(), opts :: Keyword.t()) :: Crypto.t()

  @callback verify(conn :: Plug.Conn.t(), token :: String.t(), opts) :: {:ok, term()} | verify_error

  @optional_callbacks verify: 3

  @doc false
  defguard is_key_base(value) when is_binary(value) and byte_size(value) >= 20

  @doc """
  Generates a random string in N length via `:crypto.strong_rand_bytes/1`.
  """
  @spec random_string(length :: non_neg_integer()) :: String.t()
  def random_string(length) when is_integer(length) and length >= 0 do
    :crypto.strong_rand_bytes(length) |> Base.encode64() |> binary_part(0, length)
  end

  @doc """
  """
  @spec sign(crypto :: Crypto.t(), data :: term()) :: String.t()
  def sign(%Crypto{secret_key_base: secret_key_base, salt: salt} = crypto, data)
      when is_key_base(secret_key_base) do
    Plug.Crypto.sign(
      secret_key_base,
      salt,
      data,
      to_sign_opts(crypto)
    )
  end

  @doc """
  """
  @spec verify(crypto :: Crypto.t(), token :: String.t()) :: {:ok, term()} | {:error, term()}
  def verify(%Crypto{secret_key_base: secret_key_base, salt: salt} = crypto, token) 
      when is_key_base(secret_key_base) do
    Plug.Crypto.verify(
      secret_key_base,
      salt,
      token,
      to_verify_opts(crypto)
    )
  end

  defp to_sign_opts(%Crypto{} = crypto) do
    crypto
    |> Map.take([:max_age, :key_iterations, :key_length, :key_digest, :signed_at])
    |> Enum.filter(&filter_nil_opt/1)
  end

  defp to_verify_opts(%Crypto{} = crypto) do
    crypto
    |> Map.take([:max_age, :key_iterations, :key_length, :key_digest])
    |> Enum.filter(&filter_nil_opt/1)
  end

  defp filter_nil_opt({_, value}) when value != nil, do: true
  defp filter_nil_opt(_), do: false 

end
