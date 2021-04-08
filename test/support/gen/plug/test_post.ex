defmodule Oasis.Gen.Plug.TestPost do
  use Oasis.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    json(
      conn,
      %{
        "body_params" => conn.body_params,
        "params" => conn.params
      }
    )
  end

  def handle_errors(conn, %{kind: _kind, reason: reason, stack: _stack}) do
    message = Map.get(reason, :message) || "Something went wrong"
    send_resp(conn, conn.status, message)
  end
end
