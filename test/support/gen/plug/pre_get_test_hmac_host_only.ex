defmodule Oasis.Gen.Plug.PreGetTestHMACHostOnly do
  # NOTICE: Please DO NOT write any business code in this module, since it will always be overridden when
  # run `mix oas.gen.plug` task command with the OpenAPI Specification file.
  use Oasis.Controller
  use Plug.ErrorHandler

  plug(
    Oasis.Plug.HMACAuth,
    signed_headers: "host",
    algorithm: :sha256,
    security: Oasis.Gen.HMACAuthHostOnly
  )

  def call(conn, opts) do
    conn |> super(opts) |> Oasis.Gen.Plug.GetTestHMACHostOnly.call(opts) |> halt()
  end

  defdelegate handle_errors(conn, error), to: Oasis.Gen.Plug.GetTestHMACHostOnly
end