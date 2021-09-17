defmodule Oasis.Plug.HmacAuth do
  @moduledoc false

  import Plug.Conn
  alias Oasis.BadRequestError
  require Logger

  @behaviour Plug

  @schemes_supported ~w(hmac-sha hmac-sha224 hmac-sha256 hmac-sha384 hmac-sha512 hmac-sha3_224 hmac-sha3_256 hmac-sha3_384 hmac-sha3_512 hmac-blake2b hmac-blake2s hmac-md4 hmac-md5 hmac-ripemd160)
  @scheme_mapping (for s <- @schemes_supported, into: %{} do
                     value =
                       String.split(s, "-", parts: 2)
                       |> Enum.map(&String.to_atom/1)
                       |> List.to_tuple()

                     {s, value}
                   end)
  @auth_keys ~w(Credential Signature SignedHeaders)
  @auth_key_mapping for k <- @auth_keys,
                        into: %{},
                        do: {k, k |> Recase.to_snake() |> String.to_atom()}

  def init(options), do: options

  def call(conn, options) do
    hmac_auth(conn, options)
  end

  def hmac_auth(conn, options \\ []) do
    scheme = scheme(conn, options)
    signed_headers = signed_headers(conn, options)
    security = security(conn, options)
    cryptos = security.crypto_configs(conn, options)

    with {:ok, token} <- parse_hmac_auth(conn, scheme),
         {:ok, _} <- verify(conn, token, cryptos, scheme, signed_headers),
         {:ok, _} <- security_verify(conn, security, token, options) do
      conn
    else
      {:error, e} when e in [:invalid_request, :invalid_credential, :invalid, :expired] ->
        raise_invalid_auth({:error, e})

      _ ->
        raise_invalid_auth({:error, :invalid})
    end
  end

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
      raise :invalid_token_keys
    end
  end

  defp verify(conn, token, cryptos, scheme, signed_headers) do
    with {:ok, _} <- validate_signed_headers(token, signed_headers),
         {:ok, crypto} <- load_crypto(token, cryptos),
         signature <- sign!(conn, signed_headers, crypto, scheme),
         {:ok, _} <- validate_signature(token, signature) do
      {:ok, token}
    end
  end

  defp validate_signed_headers(token, signed_headers) do
    if token.signed_headers == signed_headers do
      {:ok, token}
    else
      {:error, :invalid_request}
    end
  end

  defp load_crypto(token, cryptos) do
    cryptos
    |> Enum.find(&(&1.credential == token.credential))
    |> case do
      nil -> {:error, :invalid_credential}
      crypto -> {:ok, crypto}
    end
  end

  defp sign!(conn, signed_headers, crypto, scheme) do
    headers =
      signed_headers
      |> String.split(";")
      |> Enum.reduce([], fn header_key, acc ->
        case get_req_header(conn, header_key) do
          [value] -> [{header_key, value} | acc]
          _otherwise -> acc
        end
      end)
      |> Enum.reverse()

    method = conn.method |> to_string() |> String.upcase()
    path_and_query = conn.request_path <> "?" <> conn.query_string

    signed_header_values = headers |> Enum.map(fn {_, v} -> v end) |> Enum.join(";")

    string_to_sign =
      method
      |> Kernel.<>("\n")
      |> Kernel.<>(path_and_query)
      |> Kernel.<>("\n")
      |> Kernel.<>(signed_header_values)

    {digest_type, digest_subtype} = @scheme_mapping[scheme]

    Base.encode64(:crypto.mac(digest_type, digest_subtype, crypto.secret, string_to_sign))
  end

  defp validate_signature(token, signature) do
    if token.signature == signature do
      {:ok, token}
    else
      {:error, :invalid}
    end
  end

  defp security_verify(conn, security, token, options) do
    if function_exported?(security, :verify, 3) do
      security.verify(conn, token, options)
    else
      {:ok, conn}
    end
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

  defp parse_key_value_pair(pair, spliter),
    do: pair |> String.split(spliter, parts: 2) |> List.to_tuple()

  defp raise_invalid_auth({:error, :invalid_request}) do
    raise BadRequestError,
      error: %BadRequestError.Required{},
      message: "the hmac token is missing in the authorization header",
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
