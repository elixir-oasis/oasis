defmodule Oasis.Gen.PreGetTestHmacHostOnly do
  # NOTICE: Please DO NOT write any business code in this module, since it will always be overridden when
  # run `mix oas.gen.plug` task command with the OpenAPI Specification file.
  use Oasis.Controller
  use Plug.ErrorHandler

  plug(
    Oasis.Plug.HmacAuth,
    signed_headers: "host",
    scheme: "hmac-sha256",
    security: Oasis.Gen.HmacAuthHostOnly
  )

  def call(conn, opts) do
    conn |> super(opts) |> Oasis.Gen.GetTestHmacHostOnly.call(opts) |> halt()
  end

  defdelegate handle_errors(conn, error), to: Oasis.Gen.GetTestHmacHostOnly
end