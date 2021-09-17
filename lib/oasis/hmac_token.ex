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
        import Plug.Conn

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
          with {:ok, timestamp} <- conn |> get_header_date() |> parse_header_date() do
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
          |> get_req_header("x-oasis-date")
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
          {:error, :expired}
          | {:error, :invalid}

  @callback crypto_configs(conn :: Plug.Conn.t(), opts :: opts()) :: [Crypto.t()]

  @callback verify(conn :: Plug.Conn.t(), token :: Oasis.Plug.HmacAuth.token(), opts :: opts()) :: {:ok, term()} | verify_error()
end
