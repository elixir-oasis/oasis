defmodule Oasis.Plug.HmacAuth do
  @moduledoc ~S"""
  Functionality for providing HMAC HTTP authentication.

  It is recommended to only use this module in production if SSL is enabled and enforced.
  See `Plug.SSL` for more information.

  ## HTTP Request

  ### Authorization Header

  The client request must contains header:

  `Authorization: HMAC-uppercase(<algorithm>) Credential=<value>&SignedHeaders=<value>&Signature=<value>`

  * `Algorithm`
    * see [Schemes Supported](#module-schemes-supported) for details.
  * `Credential`
    * ID of the access key used to signature and verify, must be defined in `Oasis.HmacToken.Crypto`.
  * `SignedHeaders`
    * HTTP request header names, separated by semicolons, required to sign the request in your defined order of `x-oasis-signed-headers` spec, the HTTP headers must be correctly provided with the request as well, do not use white spaces.
  * `Signature`
    * Base64 encoded HMAC-<algorithm> hash of the String-To-Sign, it uses the value(aka Secret) of the access key identified by Credential
    * pseudo code as below:
      * `base64_encode(hmac-<algorithm>(String-To-Sign, Secret))`
  * `String-To-Sign`
    * `String-To-Sign` = `HTTP_METHOD` + `'\n'` + `path_and_query` + `'\n'` + `signed_headers_values`
    * `HTTP_METHOD`, uppercase HTTP method name used with the request.
    * `path_and_query`, concatenation of request absolute URI and query string.
    * `signed_headers_values`, semicolon-separated values of all HTTP request headers listed in `SignedHeaders`.

  ### Example
  Assume we define `x-oasis-signed-headers: x-oasis-date;host` as a part of the security scheme, the following HTTP headers in request:

  ```
  x-oasis-date: Mon, 13 Sep 2021 03:21:00 GMT
  Host: www.foo.bar
  ```

  In this case, the concatenated String-To-Sign as below:

  ```
  String-To-Sign =
  "GET" + "\\n"
  "/post?a=1&b=2" + "\\n"
  "Mon, 13 Sep 2021 03:21:00 GMT;www.foo.bar"
  ```

  Reference the best practices, the above example missing the key important variable Body of HTTP request, it should be used into the signature even if there is no body.

  Since the way to concatenate String-To-Sign is a fixed step, we can custom a new HTTP header field to represent the Body into the SignedHeaders, and keep the value of the new field in the request for the service side verification, for example:

  ```
  x-oasis-content-sha256: base64_encode(SHA256(body))
  x-oasis-content-md5: base64_encode(MD5(body))
  ```

  ## Usage

  As any other Plug, we can use the `hmac_auth/2` plug:

      # lib/pre_handler.ex
      import Oasis.Plug.HmacAuth

      plug(
        :hmac_auth,
        signed_headers: "x-oasis-date;host",
        scheme: "hmac-sha256",
        security: Oasis.Gen.HmacAuth
      )

      # lib/oasis/gen/Hmac_auth.ex
      defmodule Oasis.Gen.HmacAuth do
        @behaviour Oasis.HmacToken

        @impl true
        def crypto_configs(_conn, _options) do
          # return `Oasis.HmacToken.Crypto` struct list in your preferred way
          [
            %Oasis.HmacToken.Crypto{
              credential: "client id",
              secret: "hmac secret",
            },
            ...
          ]
        end
      end

  Or directly to Oasis.Plug.HmacAuth:

      # lib/pre_handler.ex
      plug(
        Oasis.Plug.HmacAuth,
        signed_headers: "x-oasis-date;host",
        scheme: "hmac-sha256",
        security: Oasis.Gen.HmacAuth
      )

      # lib/oasis/gen/Hmac_auth.ex
      defmodule Oasis.Gen.HmacAuth do
        @behaviour Oasis.HmacToken

        @impl true
        def crypto_configs(_conn, _options) do
          [
            ...
          ]
        end
      end



  In general, when we define the hmac security scheme like [Azure](https://docs.microsoft.com/en-us/azure/azure-app-configuration/rest-api-authentication-hmac)
  of the OpenAPI Specification in our API design document, for example:

  Here, apply the security globally to all operations:

      openapi: 3.1.0

      components:
        securitySchemes:
          hmacAuth: # arbitrary name for the security scheme
            type: http
            scheme: hmac-sha256
            x-oasis-signed-headers: x-oasis-date;host
            x-oasis-name-space: MyAuth

      security:
        - hmacAuth: []

  The above arbitrary name for the security scheme `"hmacAuth"` will be transferred into a generated module (see the mentioned "Oasis.Gen.HmacAuth"
  module) to provide the required crypto-related configuration, and use it as the value to the `:security` option of `hmac_auth/2`.

  By default, the generated "HmacAuth" module will inherit the module name space in order from the paths object, the operation object if they defined
  the `"x-oasis-name-space"` field, or defaults to `Oasis.Gen` if there are no any specification defined, as an optional, we can add an `"x-oasis-name-space"`
  field as a specification extension of the security scheme object to override the module name space, meanwhile, the optional `--name-space` argument to the
  `mix oas.gen.plug` command line is in the highest priority to set the name space of the generated module.

      components:
        securitySchemes:
          HmacAuth: # arbitrary name for the security scheme
            type: http
            scheme: hmac-sha256
            x-oasis-signed-headers: x-oasis-date;host
            x-oasis-name-space: MyAuth

  In the above example, the final generated module name of `"HmacAuth"` is `MyAuth.HmacAuth` when there is no `--name-space` argument input to generate.

  After we define Hmac authentication into the spec, then run `mix oas.gen.plug` task with this spec file (via `--file` argument), there will
  generate the above similar code to the related module file as long as it does not exist, it also follows the name space definition
  of the module, and the generation does not override it once the file existed, we need to further edit this file to provide a crypto-related
  configuration in your preferred way.

  If we need a customization to verify the Hmac token, we can implement a callback function `c:Oasis.HmacToken.verify/3`
  to this scenario.

      # lib/hmac_auth.ex
      defmodule HmacAuth do
        @behaviour Oasis.HmacToken

        @impl true
        def crypto_configs(conn, options) do
          [
            ...
          ]
        end

        @impl true
        def verify(conn, token, options) do
          # write your rules to verify the token,
          # and return the expected results in:
          #   {:ok, token}, verified
          #   {:error, :expired}, expired token
          #   {:error, :invalid}, invalid token
        end
      end

  ## Schemes Supported
  We recommend using `hmac-sha256` to verify the request, but it also supports the following schemes:
  - `hmac-sha`
  - `hmac-sha224`
  - `hmac-sha256`
  - `hmac-sha387`
  - `hmac-sha512`
  - `hmac-sha3_224`
  - `hmac-sha3_256`
  - `hmac-sha3_384`
  - `hmac-sha3_512`
  - `hmac-blake2b`
  - `hmac-blake2s`
  - `hmac-md4`
  - `hmac-md5`
  - `hmac-ripemd160`
  """

  import Plug.Conn
  alias Oasis.BadRequestError
  require Logger

  @type opts :: [
          scheme: String.t(),
          security: module(),
          signed_headers: String.t()
        ]
  @type token :: %{credential: String.t(), signed_headers: String.t(), signature: String.t()}

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

    * `:scheme`, required, see [Schemes Supported](#module-schemes-supported) for details.
    * `:security`, required, a module be with `Oasis.HmacToken` behaviour.
    * `:signed_headers`, required, defines HTTP request headers added to the signature, the provided headers are required in the request, and both in client/server side will use them into signature in the explicit definition order. (e.g., `x-oasis-date;host`)
  """
  @spec hmac_auth(conn :: Plug.Conn.t(), options :: opts()) :: Plug.Conn.t()
  def hmac_auth(conn, options) do
    options = ensure_options(conn, options)
    scheme = options[:scheme]
    security = options[:security]

    verify_result =
      with {:ok, token} <- parse_hmac_auth(conn, scheme) do
        if function_exported?(security, :verify, 3) do
          security.verify(conn, token, options)
        else
          Oasis.HmacToken.verify(conn, token, options)
        end
      end

    case verify_result do
      {:ok, _} ->
        conn

      {:error, e} when e in [:invalid_request, :invalid_credential, :invalid, :expired] ->
        raise_invalid_auth({:error, e})

      _unknown_error ->
        raise_invalid_auth({:error, :invalid})
    end
  end

  @doc """
  Parses the request token from HMAC HTTP authentication.
  """
  @spec parse_hmac_auth(conn :: Plug.Conn.t(), scheme :: String.t()) ::
          {:ok, token()} | {:error, :invalid_request}
  def parse_hmac_auth(conn, scheme) do
    try do
      {:ok, do_parse_hmac_auth!(conn, scheme)}
    rescue
      _ ->
        {:error, :invalid_request}
    end
  end

  defp do_parse_hmac_auth!(conn, scheme) do
    hmac_auth_prefix = String.upcase(scheme) <> " "
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

  defp ensure_options(conn, options) do
    scheme = scheme(conn, options)
    security = security(conn, options)
    signed_headers = signed_headers(conn, options)
    [scheme: scheme, security: security, signed_headers: signed_headers]
  end

  defp scheme(conn, options) do
    options[:scheme] ||
      raise """
      no :scheme option found in path #{conn.request_path} with plug #{inspect(__MODULE__)}.
      Please ensure your specification defines a field `scheme` in
      security scheme object, for example:

          type: http
          scheme: hmac-sha256
          x-oasis-security: HmacAuth
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
          x-oasis-security: HmacAuth
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

  defp raise_invalid_auth({:error, :invalid_request}) do
    raise BadRequestError,
      error: %BadRequestError.Required{},
      message: "the hmac token is missing in the authorization header or format is wrong",
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
      message: "the hmac token is expired",
      use_in: "header",
      param_name: "authorization",
      plug_status: 401
  end

  defp raise_invalid_auth({:error, :invalid}) do
    raise BadRequestError,
      error: %BadRequestError.InvalidToken{},
      message: "the hmac token is invalid",
      use_in: "header",
      param_name: "authorization",
      plug_status: 401
  end
end
