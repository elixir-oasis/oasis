defmodule Oasis.Plug.HMACAuth do
  @moduledoc ~S"""
  Functionality for providing HMAC HTTP authentication.

  It is recommended to only use this module in production if SSL is enabled and enforced.
  See `Plug.SSL` for more information.

  ## Usage

  As any other Plug, we can use the `hmac_auth/2` plug:

  ```elixir
  # lib/pre_handler.ex
  import Oasis.Plug.HMACAuth

  plug(
    :hmac_auth,
    signed_headers: "x-oasis-date;host",
    algorithm: :sha256,
    security: Oasis.Gen.HMACAuth
  )

  # lib/oasis/gen/HMAC_auth.ex
  defmodule Oasis.Gen.HMACAuth do
    @behaviour Oasis.HMACToken

    @impl true
    def crypto_config(_conn, _options, _credential) do
      # return `Oasis.HMACToken.Crypto` struct in your preferred way
      %Oasis.HMACToken.Crypto{
        credential: "client id",
        secret: "hmac secret",
      }
    end
  end
  ```

  Or directly to Oasis.Plug.HMACAuth:

  ```elixir
  # lib/pre_handler.ex
  plug(
    Oasis.Plug.HMACAuth,
    signed_headers: "x-oasis-date;host",
    algorithm: :sha256,
    security: Oasis.Gen.HMACAuth
  )

  # lib/oasis/gen/HMAC_auth.ex
  defmodule Oasis.Gen.HMACAuth do
    @behaviour Oasis.HMACToken

    @impl true
    def crypto_config(_conn, _options, _credential) do
      ...
    end
  end
  ```
  In general, when we define the HMAC security scheme like [Azure](https://docs.microsoft.com/en-us/azure/azure-app-configuration/rest-api-authentication-hmac)
  of the OpenAPI Specification in our API design document, for example:

  Here, apply the security globally to all operations:

  ```yaml
  openapi: 3.1.0

  components:
    securitySchemes:
      HMACAuth: # arbitrary name for the security scheme
        type: http
        scheme: hmac-sha256
        x-oasis-signed-headers: x-oasis-date;host
        x-oasis-name-space: MyAuth

  security:
    - HMACAuth: []
  ```

  The above arbitrary name for the security scheme `HMACAuth` will be transferred into a generated module (see the mentioned "Oasis.Gen.HMACAuth"
  module) to provide the required crypto-related configuration, and use it as the value to the `:security` option of `hmac_auth/2`.

  By default, the generated `HMACAuth` module will inherit the module name space in order from the paths object, the operation object if they defined
  the `x-oasis-name-space` field, or defaults to `Oasis.Gen` if there are no any specification defined, as an optional, we can add an `x-oasis-name-space`
  field as a specification extension of the security scheme object to override the module name space, meanwhile, the optional `--name-space` argument to the
  `mix oas.gen.plug` command line is in the highest priority to set the name space of the generated module.

  ```yaml
  components:
    securitySchemes:
      HMACAuth: # arbitrary name for the security scheme
        type: http
        scheme: hmac-sha256
        x-oasis-signed-headers: x-oasis-date;host
        x-oasis-name-space: MyAuth
  ```

  In the above example, the final generated module name of `HMACAuth` is `MyAuth.HMACAuth` when there is no `--name-space` argument input to generate.

  After we define HMAC authentication into the spec, then run `mix oas.gen.plug` task with this spec file (via `--file` argument), there will
  generate the above similar code to the related module file as long as it does not exist, it also follows the name space definition
  of the module, and the generation does not override it once the file existed, we need to further edit this file to provide a crypto-related
  configuration in your preferred way.

  If we need a customization to verify the HMAC token, we can implement a callback function `c:Oasis.HMACToken.verify/3`
  to this scenario.

  ```elixir
  # lib/hmac_auth.ex
  defmodule HMACAuth do
    @behaviour Oasis.HMACToken

    @impl true
    def crypto_config(conn, options, credential) do
      ...
    end

    @impl true
    def verify(conn, token, options) do
      # write your rules to verify the token,
      # and return the expected results in:
      #   {:ok, token}, verified
      #   {:error, :expired}, expired token
      #   {:error, :invalid_token}, invalid token
    end
  end
  ```

  ## Algorithms Supported
  We recommend using `sha256` to verify the request, but it also supports the following schemes:
  - `sha`
  - `sha224`
  - `sha256`
  - `sha387`
  - `sha512`
  - `sha3_224`
  - `sha3_256`
  - `sha3_384`
  - `sha3_512`
  - `blake2b`
  - `blake2s`
  - `md4`
  - `md5`
  - `ripemd160`

  You could see [Erlang/OTP docs - HMAC](https://erlang.org/doc/apps/crypto/algorithm_details.html#hmac)  for more details.
  """

  import Plug.Conn
  alias Oasis.BadRequestError
  require Logger

  @type algorithm ::
          :sha
          | :sha224
          | :sha256
          | :sha384
          | :sha512
          | :sha3_224
          | :sha3_256
          | :sha3_384
          | :sha3_512
          | :blake2b
          | :blake2s
          | :md4
          | :md5
          | :ripemd160

  @type opts :: [
          algorithm: algorithm(),
          security: module(),
          signed_headers: String.t()
        ]

  @behaviour Plug

  @auth_keys ~w(Credential Signature SignedHeaders)
  @auth_key_mapping for k <- @auth_keys,
                        into: %{},
                        do: {k, k |> Recase.to_snake() |> String.to_atom()}

  def init(options), do: options

  def call(conn, options) do
    hmac_auth(conn, options)
  end

  @doc """
  Higher level usage of HMAC HTTP authentication.

  See the module docs for examples.

  ## Options

    * `:algorithm`, required, see [Algorithms Supported](#module-algorithms-supported) for details.
    * `:security`, required, a module be with `Oasis.HMACToken` behaviour.
    * `:signed_headers`, required, defines HTTP request headers added to the signature, the provided headers are required in the request, and both in client/server side will use them into signature in the explicit definition order. (e.g., `x-oasis-date;host`)
  """
  @spec hmac_auth(conn :: Plug.Conn.t(), options :: opts()) :: Plug.Conn.t()
  def hmac_auth(conn, options) do
    options = ensure_options(conn, options)
    algorithm = options[:algorithm]
    security = options[:security]
    signed_headers = options[:signed_headers]

    verify_result =
      with {:ok, token} <- parse_hmac_auth(conn, algorithm),
           {:ok, _} <- validate_signed_headers(token, signed_headers) do
        if Code.ensure_loaded?(security) and function_exported?(security, :verify, 3) do
          security.verify(conn, token, options)
        else
          Oasis.HMACToken.verify(conn, token, options)
        end
      end

    case verify_result do
      {:ok, _} ->
        conn

      {:error, e} when e in [:header_mismatch, :invalid_credential, :invalid_token, :expired] ->
        raise_invalid_auth({:error, e})

      _unknown_error ->
        raise_invalid_auth({:error, :invalid_token})
    end
  end

  @doc """
  Parses the request token from HMAC HTTP authentication.
  """
  @spec parse_hmac_auth(conn :: Plug.Conn.t(), algorithm :: algorithm()) ::
          {:ok, Oasis.HMACToken.token()} | {:error, :header_mismatch}
  def parse_hmac_auth(conn, algorithm) do
    try do
      {:ok, do_parse_hmac_auth!(conn, algorithm)}
    rescue
      _ ->
        {:error, :header_mismatch}
    end
  end

  defp do_parse_hmac_auth!(conn, algorithm) do
    hmac_auth_prefix = "HMAC-#{algorithm |> to_string() |> String.upcase()} "
    [authorization] = get_req_header(conn, "authorization")

    token =
      authorization
      |> String.trim_leading(hmac_auth_prefix)
      |> String.split("&")
      |> Stream.map(&parse_key_value_pair(&1, "="))
      |> Stream.filter(fn {k, _} -> k in Map.keys(@auth_key_mapping) end)
      |> Stream.map(fn {k, v} -> {Map.fetch!(@auth_key_mapping, k), v} end)
      |> Enum.into(%{})

    keys_expect = @auth_key_mapping |> Map.values() |> Enum.sort()
    keys_actual = token |> Map.keys() |> Enum.sort()

    if keys_expect == keys_actual do
      token
    else
      raise "invalid_token_keys"
    end
  end

  defp validate_signed_headers(token, signed_headers) do
    if token.signed_headers == signed_headers do
      {:ok, token}
    else
      {:error, :header_mismatch}
    end
  end

  defp ensure_options(conn, options) do
    algorithm = algorithm(conn, options)
    security = security(conn, options)
    signed_headers = signed_headers(conn, options)
    [algorithm: algorithm, security: security, signed_headers: signed_headers]
  end

  defp algorithm(conn, options) do
    options[:algorithm] ||
      raise """
      no :scheme option found in path #{conn.request_path} with plug #{inspect(__MODULE__)}.
      Please ensure your specification defines a field `scheme` in
      security scheme object, for example:

          type: http
          scheme: hmac-sha256
          x-oasis-security: HMACAuth
          x-oasis-signed-headers: x-oasis-date;host
      """
  end

  defp signed_headers(conn, options) do
    options[:signed_headers] ||
      raise """
      no :signed_headers option found in path #{conn.request_path} with plug #{inspect(__MODULE__)}.
      Please ensure your specification defines a field `x-oasis-signed-headers` in
      security scheme object, for example:

          type: http
          scheme: hmac-sha256
          x-oasis-security: HMACAuth
          x-oasis-signed-headers: x-oasis-date;host
      """
  end

  defp security(conn, options) do
    options[:security] ||
      raise """
      no :security option found in path #{conn.request_path} with plug #{inspect(__MODULE__)}.
      Please ensure your specification defines a valid field `x-oasis-name-space` in
      security scheme object or use oasis default value, for example:

          type: http
          scheme: hmac-sha256
          x-oasis-signed-headers: x-oasis-date;host
          x-oasis-name-space: MyOwnApplication
      """
  end

  defp parse_key_value_pair(pair, splitter),
    do: pair |> String.split(splitter, parts: 2) |> List.to_tuple()

  defp raise_invalid_auth({:error, :header_mismatch}) do
    raise BadRequestError,
      error: %BadRequestError.Required{},
      message: "the HMAC token is missing in the authorization header or format is wrong",
      use_in: "header",
      param_name: "authorization"
  end

  defp raise_invalid_auth({:error, :invalid_credential}) do
    raise BadRequestError,
      error: %BadRequestError.Required{},
      message: "the credential in the authorization header is not assigned",
      use_in: "header",
      param_name: "authorization"
  end

  defp raise_invalid_auth({:error, :expired}) do
    raise BadRequestError,
      error: %BadRequestError.InvalidToken{},
      message: "the HMAC token is expired",
      use_in: "header",
      param_name: "authorization",
      plug_status: 401
  end

  defp raise_invalid_auth({:error, :invalid_token}) do
    raise BadRequestError,
      error: %BadRequestError.InvalidToken{},
      message: "the HMAC token is invalid",
      use_in: "header",
      param_name: "authorization",
      plug_status: 401
  end
end
