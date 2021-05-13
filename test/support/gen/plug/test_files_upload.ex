defmodule Oasis.Gen.Plug.TestFilesUpload do
  use Oasis.Controller

  alias Oasis.BadRequestError

  def init(opts), do: opts

  def call(conn, _opts) do
    with_logo =
      case conn.body_params["logo"] do
        %Plug.Upload{} -> true
        _ -> false
      end

    json(
      conn,
      %{
        "uploaded" => length(conn.body_params["file"] || []),
        "with_logo" => with_logo
      }
    )
  end

  def handle_errors(conn, %{kind: _kind, reason: %BadRequestError{error: %BadRequestError.JsonSchemaValidationFailed{} = json_schema} = reason, stack: _stack}) do
    message = "Find #{reason.use_in} parameter `#{reason.param_name}` with error: #{to_string(json_schema.error)}"
    send_resp(conn, conn.status, message)
  end
end
