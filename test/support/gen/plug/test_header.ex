defmodule Oasis.Gen.Plug.TestHeader do
  use Oasis.Controller

  alias Oasis.BadRequestError

  def init(opts), do: opts

  def call(conn, _opts) do
    conn = fetch_query_params(conn)
    if Map.has_key?(conn.query_params, "raise") do
      raise "oops"
    else
      json(conn, Map.new(conn.req_headers))
    end
  end

  def handle_errors(conn, %{kind: _kind, reason: %BadRequestError{error: %BadRequestError.JsonSchemaValidationFailed{} = json_schema} = reason, stack: _stack}) do
    message = "Find #{reason.use_in} parameter `#{reason.param_name}` with error: #{to_string(json_schema.error)}"
    send_resp(conn, conn.status, message)
  end
  def handle_errors(conn, %{kind: _kind, reason: reason, stack: _stack}) do
    message = Map.get(reason, :message) || "Something went wrong"
    send_resp(conn, conn.status, message)
  end
end
