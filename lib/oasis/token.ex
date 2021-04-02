defmodule Oasis.Token do
  @moduledoc ~S"""
  A simple wrapper of `Plug.Crypto` to provide a way to generate and verify bearer token for use
  in the [bearer security scheme](https://github.com/OAI/OpenAPI-Specification/blob/master/versions/3.1.0.md#securitySchemeObject)
  of the OpenAPI Specification.

  When we use `sign/2` and `verify/2`, the data stored in the token is signed to
  prevent tampering but not encrypted, in this scenario, we can store identification information
  (such as user NON-PII data), but *SHOULD NOT* be used to store confidential information
  (such as credit card numbers, PIN code).

  \* "NON-PII" means Non Personally Identifiable Information.

  If you don't want clients to be able to determine the value of the token, you may use `encrypt/2`
  and `decrypt/2` to generate and verify the token.

  ## Callback

  There are two callback functions reserved for use in the generated modules when we use the bearer security
  scheme of the OpenAPI Specification.

  * `c:crypto_config/2`, provides a way to define the crypto-related key information for the high level useage,
    it required to return a `#{inspect(__MODULE__)}.Crypto` struct.
  * `c:verify/3`, an optional function to provide a way to custom the verification of the token, you may
    want to use encrypt/decrypt to the token, or other more rules to verify it.
  """

  defmodule Crypto do
    @moduledoc """
    A module to represent crypto-related key information.

    All fields of `#{inspect(__MODULE__)}` are completely map to:

    * `Plug.Crypto.encrypt/4` and `Plug.Crypto.decrypt/4`
    * `Plug.Crypto.sign/4` and `Plug.Crypto.verify/4`

    Please refer the above functions for details to construct it.

    In general, when we define a bearer security scheme of the OpenAPI Specification,
    the generated module will use this struct to define the required crypto-related
    key information.

    Please note that the value of the `:secret_key_base` field is required to be a string at least 20 length.
    """

    @enforce_keys [:secret_key_base]

    defstruct [
      :secret_key_base,
      :secret,
      :salt,
      :key_iterations,
      :key_length,
      :key_digest,
      :signed_at,
      :max_age
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

  @doc """
  Avoid using the application enviroment as the configuration mechanism for this library,
  and make crypto-related key information configurable when use bearer authentication.

  The `Oasis.Plug.BearerAuth` module invokes this callback function to fetch a predefined
  `#{inspect(__MODULE__)}.Crypto` struct, and then use it to verify the bearer token of the request.
  """
  @callback crypto_config(conn :: Plug.Conn.t(), opts :: Keyword.t()) :: Crypto.t()

  @doc """
  An optional callback function to decode the original data from the token, and verify
  its integrity.

  If we use `sign/2` to create a token, sign it, then provide it to a client application,
  the client will then use this token to authenticate requests for resources from the server,
  in this scenario, as a common use case, the `Oasis.Plug.BearerAuth` module uses `verify/2`
  to finish the verification of the bearer token, so we do not need to implement this
  callback function in general.

  But if we use `encrypt/2` or other encryption methods to encode, encrypt, and sign data into a token
  and send to clients, we need to implement this callback function to custom the way to decrypt
  the token and verify its integrity.
  """
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
  A wrapper of `Plug.Crypto.sign/4` to use `#{inspect(__MODULE__)}.Crypto` to sign data
  into a token you can send to clients, please see `Plug.Crypto.sign/4` for details.
  """
  @spec sign(crypto :: Crypto.t(), data :: term()) :: String.t()
  def sign(%Crypto{secret_key_base: secret_key_base, salt: salt} = crypto, data)
      when is_key_base(secret_key_base) do
    Plug.Crypto.sign(
      secret_key_base,
      salt,
      data,
      to_encrypt_opts(crypto)
    )
  end

  @doc """
  A wrapper of `Plug.Crypto.verify/4` to use `#{inspect(__MODULE__)}.Crypto` to decode the original
  data from the token and verify its integrity, please see `Plug.Crypto.verify/4` for details.
  """
  @spec verify(crypto :: Crypto.t(), token :: String.t()) :: {:ok, term()} | {:error, term()}
  def verify(%Crypto{secret_key_base: secret_key_base, salt: salt} = crypto, token) 
      when is_key_base(secret_key_base) do
    Plug.Crypto.verify(
      secret_key_base,
      salt,
      token,
      to_decrypt_opts(crypto)
    )
  end

  @doc """
  A wrapper of `Plug.Crypto.encrypt/4` to use `#{inspect(__MODULE__)}.Crypto` to encode, encrypt and
  sign data into a token you can send to clients, please see `Plug.Crypto.encrypt/4` for details.
  """
  @spec encrypt(crypto :: Crypto.t(), data :: term()) :: String.t()
  def encrypt(%Crypto{secret_key_base: secret_key_base, secret: secret} = crypto, data)
      when is_key_base(secret_key_base) do
    Plug.Crypto.encrypt(
      secret_key_base,
      secret,
      data,
      to_encrypt_opts(crypto)
    )
  end

  @doc """
  A wrapper of `Plug.Crypto.decrypt/4` to use `#{inspect(__MODULE__)}.Crypto` to decrypt the original data
  from the token and verify its integrity, please see `Plug.Crypto.decrypt/4` for details.
  """
  def decrypt(%Crypto{secret_key_base: secret_key_base, secret: secret} = crypto, token)
      when is_key_base(secret_key_base) do
    Plug.Crypto.decrypt(
      secret_key_base,
      secret,
      token,
      to_decrypt_opts(crypto)
    )
  end

  defp to_encrypt_opts(%Crypto{} = crypto) do
    crypto
    |> Map.take([:max_age, :key_iterations, :key_length, :key_digest, :signed_at])
    |> Enum.filter(&filter_nil_opt/1)
  end

  defp to_decrypt_opts(%Crypto{} = crypto) do
    crypto
    |> Map.take([:max_age, :key_iterations, :key_length, :key_digest])
    |> Enum.filter(&filter_nil_opt/1)
  end

  defp filter_nil_opt({_, value}) when value != nil, do: true
  defp filter_nil_opt(_), do: false 

end
