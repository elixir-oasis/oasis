defmodule Oasis.Plug.BearerAuth do
  @moduledoc ~S"""
  TODO
  """
  import Plug.Conn

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
      Please ensure your specification defines a field `x-oasis-security` in 
      security scheme object, for example:

          type: http
          scheme: bearer
          x-oasis-security: BearerAuth
      """
  end

  defp raise_invalid_auth({:error, "invalid_request"}) do
    raise Oasis.InvalidRequest,
      message: "missing a token in authorization header"
  end
  defp raise_invalid_auth({:error, "expired_token"}) do
    raise Oasis.InvalidTokenRequest,
      message: "the provided token is expired"
  end
  defp raise_invalid_auth({:error, "invalid_token"}) do
    raise Oasis.InvalidTokenRequest,
      message: "the provided token is invalid"
  end

end
