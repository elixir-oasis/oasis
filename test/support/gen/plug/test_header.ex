defmodule Oasis.Gen.Plug.TestHeader do
  import Plug.Conn

  @behaviour Plug

  def init(opts), do: opts

  def call(conn, _opts) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(Map.new(conn.req_headers)))
  end

  def handle_errors(conn, %{kind: _kind, reason: reason, stack: _stack}) do
    message = reason.message || "Something went wrong"
    send_resp(conn, conn.status, message)
  end
end
