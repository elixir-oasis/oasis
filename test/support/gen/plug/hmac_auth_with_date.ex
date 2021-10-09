defmodule Oasis.Gen.HMACAuthWithDate do
  # NOTICE: This module is generated when run `mix oas.gen.plug` task command with the OpenAPI Specification file
  # in the first time, and then it WILL NOT be modified in the future generation command(s) once this file exists,
  # please write the crypto-related configuration to the bearer token in this module.
  @behaviour Oasis.HMACToken
  alias Oasis.HMACToken.Crypto
  # in seconds
  @max_diff 60

  @impl true
  def crypto_config(_conn, _opts, "test_client") do
    %Crypto{
      credential: "test_client",
      secret: "secret"
    }
  end

  def crypto_config(_conn, _opts, _credential), do: nil

  @impl true
  def verify(conn, token, opts) do
    with {:ok, _} <- Oasis.HMACToken.verify_signature(conn, token, opts),
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
    with {:ok, datetime, _} <- DateTime.from_iso8601(str) ,
         timestamp when is_integer(timestamp) <- DateTime.to_unix(datetime) do
      {:ok, timestamp}
    end
  end

  defp parse_header_date(_otherwise), do: {:error, :expired}
end
