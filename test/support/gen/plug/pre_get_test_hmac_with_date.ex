defmodule Oasis.Gen.PreGetTestHmacWithDate do
  # NOTICE: Please DO NOT write any business code in this module, since it will always be overridden when
  # run `mix oas.gen.plug` task command with the OpenAPI Specification file.
  use Oasis.Controller
  use Plug.ErrorHandler

  plug(
    Oasis.Plug.HmacAuth,
    signed_headers: "host;x-oasis-date",
    scheme: "hmac-sha256",
    security: Oasis.Gen.HmacAuthWithDate
  )

  def call(conn, opts) do
    conn |> super(opts) |> Oasis.Gen.GetTestHmacWithDate.call(opts) |> halt()
  end

  defdelegate handle_errors(conn, error), to: Oasis.Gen.GetTestHmacWithDate
end