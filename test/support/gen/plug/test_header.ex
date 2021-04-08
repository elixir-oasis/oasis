defmodule Oasis.Gen.Plug.TestHeader do
  use Oasis.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    conn = fetch_query_params(conn)
    if Map.has_key?(conn.query_params, "raise") do
      raise "oops"
    else
      json(conn, Map.new(conn.req_headers))
    end
  end

  def handle_errors(conn, %{kind: _kind, reason: reason, stack: _stack}) do
    message = Map.get(reason, :message) || "Something went wrong"
    send_resp(conn, conn.status, message)
  end
end
