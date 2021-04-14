defmodule Oasis.Gen.Plug.TestBearerAuth do
  use Oasis.Controller

  alias Oasis.BadRequestError

  def init(opts), do: opts

  def call(conn, _opts) do
    json(conn, %{"id" => conn.assigns.id})
  end

  def handle_errors(conn, %{kind: _kind, reason: %BadRequestError{error: %BadRequestError.Required{}, message: message} = reason, stack: _stack}) do
    conn = Oasis.Plug.BearerAuth.request_bearer_auth(conn, error: {"invalid_request", message})
    conn = put_in(conn.status, reason.plug_status)
    json(conn, %{"status" => "invalid request"})
  end
  def handle_errors(conn, %{kind: _kind, reason: %BadRequestError{error: %BadRequestError.InvalidToken{}, message: message} = reason, stack: _stack}) do
    conn = Oasis.Plug.BearerAuth.request_bearer_auth(conn, error: {"invalid_token", message})
    conn = put_in(conn.status, reason.plug_status)
    json(conn, %{"status" => "invalid token"})
  end
  def handle_errors(conn, %{kind: _kind, reason: reason, stack: _stack}) do
    message = Map.get(reason, :message) || "Something went wrong"
    send_resp(conn, conn.status, message)
  end

end
