defmodule <%= inspect context.module_name %> do
  # NOTICE: This module is generated from the corresponding mix task command with the OpenAPI Specification file
  # in the first time running, and then it WON'T be modified in the future generation command(s)
  # once this file exists, please write your business code in this module.
  use Oasis.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    # TODO
    conn
  end

  def handle_errors(conn, %{kind: _kind, reason: reason, stack: _stack}) do
    message = Map.get(reason, :message, "Something went wrong")
    send_resp(conn, conn.status, message)
  end
end
