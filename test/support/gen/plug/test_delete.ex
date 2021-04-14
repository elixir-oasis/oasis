defmodule Oasis.Gen.Plug.TestDelete do
  use Oasis.Controller

  alias Oasis.BadRequestError

  def init(opts), do: opts

  def call(conn, _opts) do
    json(
      conn,
      %{
        "conn_params" => conn.params,
        "query_params" => conn.query_params,
        "body_params" => conn.body_params
      }
    )
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
