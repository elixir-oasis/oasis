defmodule Oasis.HmacToken do
  @moduledoc """
  ## Callback

  There are two callback functions reserved for use in the generated modules when we use the hmac security
  scheme of the OpenAPI Specification.

  * `c:crypto_configs/2`, provides a way to define the crypto-related key information for the high level usage,
    it required to return a list of `#{inspect(__MODULE__)}.Crypto` struct.
  * `c:verify/3`, an optional function to provide a way to custom the verification of the token, you may
    want to validate request datetime, or other more rules to verify it.


  ## Example

  Here is an example to verify that HTTP request time does not exceed the current time by 1 minute.

      defmodule Oasis.Gen.HmacAuth do
        @behaviour Oasis.HmacToken
        alias Oasis.HmacToken.Crypto

        # in seconds
        @max_diff 60

        @impl true
        def crypto_configs(_conn, _opts) do
          [
            %Crypto{
              credential: "...",
              secret: "..."
            }
          ]
        end

        @impl true
        def verify(conn, token, _opts) do
          with {:ok, _} <- Oasis.HmacToken.verify_signature(conn, token, opts),
               {:ok, timestamp} <- conn |> get_header_date() |> parse_header_date() do
            timestamp_now = DateTime.utc_now() |> DateTime.to_unix()

            if timestamp_now - timestamp < @max_diff do
              {:ok, timestamp}
            else
              {:error, :expired}
            end
          end
        end

        defp get_header_date(conn) do
          conn
          |> Plug.Conn.get_req_header("x-oasis-date")
          |> case do
            [date] -> date
            _ -> nil
          end
        end

        defp parse_header_date(str) when is_binary(str) do
          with {:ok, datetime} <- Timex.parse(str, "%a, %d %b %Y %H:%M:%S GMT", :strftime),
               timestamp when is_integer(timestamp) <- Timex.to_unix(datetime) do
            {:ok, timestamp}
          end
        end

        defp parse_header_date(_otherwise), do: {:error, :expired}
      end
  """

  defmodule Crypto do
    @moduledoc """
    In general, when we define a hmac security scheme of the OpenAPI Specification,
    the generated module will use this struct to define the required crypto-related
    key information.
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
          {:error, :invalid_request}
          | {:error, :invalid_credential}
          | {:error, :invalid}
          | {:error, :expired}

  @callback crypto_configs(conn :: Plug.Conn.t(), opts :: Keyword.t()) :: [Crypto.t()]

  @callback verify(conn :: Plug.Conn.t(), token :: Oasis.Plug.HmacAuth.token(), opts :: opts()) ::
              {:ok, term()} | verify_error()

  @optional_callbacks verify: 3

  @schemes_supported ~w(hmac-sha hmac-sha224 hmac-sha256 hmac-sha384 hmac-sha512 hmac-sha3_224 hmac-sha3_256 hmac-sha3_384 hmac-sha3_512 hmac-blake2b hmac-blake2s hmac-md4 hmac-md5 hmac-ripemd160)
  @scheme_mapping (for s <- @schemes_supported, into: %{} do
                     value =
                       String.split(s, "-", parts: 2)
                       |> Enum.map(&String.to_atom/1)
                       |> List.to_tuple()

                     {s, value}
                   end)

  @doc """
    Default implementation of the callback `verify`, only verify the signature.

    See `verify_signature/3` for details.
  """
  defdelegate verify(conn, token, opts), to: __MODULE__, as: :verify_signature

  @doc """
  Verify the signature in `token`.
  """
  @spec verify_signature(
          conn :: Plug.Conn.t(),
          token :: Oasis.Plug.HmacAuth.token(),
          opts :: Oasis.Plug.HmacAuth.opts()
        ) :: {:ok, term()} | verify_error()
  def verify_signature(conn, token, opts) do
    scheme = opts[:scheme]
    signed_headers = opts[:signed_headers]
    security = opts[:security]
    cryptos = security.crypto_configs(conn, opts)

    with {:ok, _} <- validate_signed_headers(token, signed_headers),
         {:ok, crypto} <- load_crypto(token, cryptos),
         signature <- sign!(conn, signed_headers, crypto, scheme),
         {:ok, _} <- validate_signature(token, signature) do
      {:ok, token}
    end
  end

  @doc """
  Sign HTTP requests according to settings.

  See [HTTP Request](Oasis.Plug.HmacAuth.html#module-http-request) for details.
  """
  @spec sign!(
          conn :: Plug.Conn.t(),
          signed_headers :: String.t(),
          crypto :: Crypto.t(),
          scheme :: String.t()
        ) :: String.t()
  def sign!(conn, signed_headers, crypto, scheme) do
    headers =
      signed_headers
      |> String.split(";")
      |> Enum.reduce([], fn header_key, acc ->
        case Plug.Conn.get_req_header(conn, header_key) do
          [value] -> [{header_key, value} | acc]
          _otherwise -> acc
        end
      end)
      |> Enum.reverse()

    method = conn.method |> to_string() |> String.upcase()
    path_and_query = build_path_and_query(conn.request_path, conn.query_string)

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

  defp build_path_and_query(path, nil), do: path
  defp build_path_and_query(path, ""), do: path
  defp build_path_and_query(path, query), do: path <> "?" <> query

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

  defp validate_signature(token, signature) do
    if token.signature == signature do
      {:ok, token}
    else
      {:error, :invalid}
    end
  end
end
