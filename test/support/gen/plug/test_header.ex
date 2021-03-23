defmodule Oasis.Gen.Plug.TestHeader do
  use Oasis.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    json(conn, Map.new(conn.req_headers))
  end

  def handle_errors(conn, %{kind: _kind, reason: reason, stack: _stack}) do
    message = reason.message || "Something went wrong"
    send_resp(conn, conn.status, message)
  end
end
