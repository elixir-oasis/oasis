defmodule Oasis.Plug.BearerAuth do
  @moduledoc ~S"""
  Functionality for providing Bearer HTTP authentication.

  It is recommended to only use this module in production if SSL is enabled and enforced.
  See `Plug.SSL` for more information.

  ## Example

  As any other Plug, we can use the `bearer_auth/2` plug:

      # lib/pre_handler.ex
      import Oasis.Plug.BearerAuth

      plug :bearer_auth,
        security: Oasis.Gen.BearerAuth
        key_to_assigns: :user_id

      # lib/oasis/gen/bearer_auth.ex
      defmodule Oasis.Gen.BearerAuth do
        @behaviour Oasis.Token

        @impl true
        def crypto_config(_conn, _options) do
          # return a `Oasis.Token.Crypto` struct in your preferred way
          %Oasis.Token.Crypto{
            secret_key_base: "...",
            salt: "...",
            max_age: 7200
          }
        end
      end

  Or directly to Oasis.Plug.BearerAuth:

      # lib/pre_handler.ex

      plug(
        Oasis.Plug.BearerAuth,
        security: Oasis.Gen.BearerAuth,
        key_to_assigns: :user_id
      )

      # lib/oasis/gen/bearer_auth.ex
      defmodule Oasis.Gen.BearerAuth do
        @behaviour Oasis.Token

        @impl true
        def crypto_config(_conn, _options) do
          # ...
        end
      end


  In general, when we define the [bearer security scheme](https://github.com/OAI/OpenAPI-Specification/blob/master/versions/3.1.0.md#securitySchemeObject)
  of the OpenAPI Specification in our API design document, for example:

  Here, apply the security globally to all operations:

      openapi: 3.1.0

      components:
        securitySchemes:
          bearerAuth: # arbitrary name for the security scheme
            type: http
            scheme: bearer
            bearerFormat: JWT

      security:
        - bearerAuth: []

  Here, apply the security to a operation, and define an optional specification extension `"x-oasis-key-to-assigns"` field
  to the `:key_to_assigns` option of `bearer_auth/2`:

      openapi: 3.1.0

      components:
        securitySchemes:
          bearerAuth: # arbitrary name for the security scheme
            type: http
            scheme: bearer
            bearerFormat: JWT
            x-oasis-key-to-assigns: user_id

      paths:
        /something:
          get:
            security:
              - bearerAuth: []

  The above arbitrary name for the security scheme `"bearerAuth"` will be transferred into a generated module (see the mentioned "Oasis.Gen.BearerAuth"
  module) to provide the required crypto-related configuration, and use it as the value to the `:security` option of `bearer_auth/2`.

  By default, the generated "BearerAuth" module will inherit the module name space in order from the paths object, the operation object if they defined
  the `"x-oasis-name-space"` field, or defaults to `Oasis.Gen` if there are no any specification defined, as an optional, we can add an `"x-oasis-name-space"`
  field as a specification extension of the security scheme object to override the module name space, meanwhile, the optional `--name-space` argument to the
  `mix oas.gen.plug` command line is in the highest priority to set the name space of the generated module.

      components:
        securitySchemes:
          bearerAuth: # arbitrary name for the security scheme
            type: http
            scheme: bearer
            bearerFormat: JWT
            x-oasis-key-to-assigns: user_id
            x-oasis-name-space: MyToken

  In the above example, the final generated module name of `"bearerAuth"` is `MyToken.BearerAuth` when there is no `--name-space` argument input to generate.

  After we define bearer authentication into the spec, then run `mix oas.gen.plug` task with this spec file (via `--file` argument), there will
  generate the above similar code to the related module file as long as it does not exist, it also follows the name space definition
  of the module, and the generation does not override it once the file existed, we need to further edit this file to provide a crypto-related
  configuration in your preferred way.

  If we need a customization to verify the bearer token, we can implement a callback function `c:Oasis.Token.verify/3`
  to this scenario.

      # lib/bearer_auth.ex
      defmodule BearerAuth do
        @behaviour Oasis.Token

        @impl true
        def crypto_config(conn, options) do
          %Oasis.Token.Crypto{
            ...
          }
        end

        @impl true
        def verify(conn, token, options) do
          # write your rules to verify the token,
          # and return the expected results in:
          #   {:ok, data}, verified
          #   {:error, :expired}, expired token
          #   {:error, :invalid}, invalid token
        end
      end
  """
  import Plug.Conn
  alias Oasis.BadRequestError

  @behaviour Plug

  def init(options), do: options

  def call(conn, options) do
    bearer_auth(conn, options)
  end

  @doc """
  Higher level usage of Baerer HTTP authentication.

  See the module docs for examples.

  ## Options

    * `:security`, required, a module be with `Oasis.Token` behaviour.
    * `:key_to_assigns`, optional, after the verification of the token, the original data
      will be stored into the `conn.assigns` once this option defined, for example, if set
      it as `:user_id`, we can access the verified data via `conn.assigns.user_id` in the
      next plug pipeline.
  """
  def bearer_auth(conn, options \\ []) do
    with {:ok, token} <- parse_bearer_auth(conn),
         {conn, security, crypto} <- load_crypto(conn, options),
         {:ok, data} <- verify(conn, security, crypto, token, options) do
      key = Keyword.get(options, :key_to_assigns)
      if key != nil do
        assign(conn, key, data)
      else
        conn
      end
    else
      error ->
        raise_invalid_auth(error)
    end
  end

  @doc """
  Parses the request token from Bearer HTTP authentication.

  It returns either `{:ok, token}` or `{:error, "invalid_request"}`.
  """
  def parse_bearer_auth(conn) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization") do
      {:ok, token}
    else
      _ -> {:error, "invalid_request"}
    end
  end

  @doc """
  Requests bearer authentication from the client.

  It sets the response to status 401 with "Unauthorized" as body.
  The response is not sent though (nor the connection is halted),
  allowing developers to further customize it.

  A response example:

      HTTP/1.1 401 Unauthorized
      www-authenticate: Bearer realm="Application",
                        error="invalid_token",
                        error_description="the access token expired"

  ## Options

    * `:realm` - the authentication realm. The value is not fully
      sanitized, so do not accept user input as the realm and use
      strings with only alphanumeric characters and space.
    * `:error` - an optional tuple to represent `"error"` and `"error_description"`
      attributes, for example, `{"invalid_token", "the access token expired"}`
  """
  def request_bearer_auth(conn, options \\ []) when is_list(options) do
    conn
    |> put_resp_header("www-authenticate", www_authenticate_header(options))
    |> resp(401, "Unauthorized")
  end

  defp www_authenticate_header(options) do
    realm = Keyword.get(options, :realm, "Application")
    escaped_realm = String.replace(realm, "\"", "")

    case Keyword.get(options, :error) do
      {error_code, error_desc} ->
        "Bearer realm=\"#{escaped_realm}\",error=\"#{error_code}\",error_description=\"#{error_desc}\""
      _ ->
        "Bearer realm=\"#{escaped_realm}\""
    end
  end

  defp load_crypto(conn, options) do
    security = security(conn, options)
    crypto = security.crypto_config(conn, options)
    conn = put_in(conn.secret_key_base, crypto.secret_key_base)
    {conn, security, crypto}
  end

  defp verify(conn, security, crypto, token, options) do
    result =
      if function_exported?(security, :verify, 3) == true do
        security.verify(conn, token, options)
      else
        Oasis.Token.verify(crypto, token) 
      end

    case result do
      {:ok, _} ->
        result
      {:error, :expired} ->
        {:error, "expired_token"}
      {:error, _invalid} ->
        {:error, "invalid_token"}
    end
  end

  defp security(conn, options) do
    options[:security] ||
      raise """
      no :security option found in path #{conn.request_path} with plug #{inspect(__MODULE__)}.
      Please ensure your specification defines a valid `x-oasis-name-space` in
      security scheme object or use oasis default value, for example:

          type: http
          scheme: bearer
          x-oasis-name-space: MyOwnApplication
      """
  end

  defp raise_invalid_auth({:error, "invalid_request"}) do
    raise BadRequestError,
      error: %BadRequestError.Required{},
      message: "the bearer token is missing in the authorization header",
      use_in: "header",
      param_name: "authorization"
  end
  defp raise_invalid_auth({:error, "expired_token"}) do
    raise BadRequestError,
      error: %BadRequestError.InvalidToken{},
      message: "the bearer token is expired",
      use_in: "header",
      param_name: "authorization",
      plug_status: 401
  end
  defp raise_invalid_auth({:error, "invalid_token"}) do
    raise BadRequestError,
      error: %BadRequestError.InvalidToken{},
      message: "the bearer token is invalid",
      use_in: "header",
      param_name: "authorization",
      plug_status: 401
  end

end
