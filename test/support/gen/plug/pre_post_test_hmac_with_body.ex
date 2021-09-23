defmodule Oasis.Gen.PrePostTestHmacWithBody do
  # NOTICE: Please DO NOT write any business code in this module, since it will always be overridden when
  # run `mix oas.gen.plug` task command with the OpenAPI Specification file.
  use Oasis.Controller
  use Plug.ErrorHandler

  plug(
    Plug.Parsers,
    parsers: [:json],
    json_decoder: Jason,
    pass: ["*/*"],
    body_reader: {Oasis.CacheRawBodyReader, :read_body, []}
  )

  plug(
    Oasis.Plug.RequestValidator,
    body_schema: %{
      "content" => %{
        "application/json" => %{
          "schema" => %ExJsonSchema.Schema.Root{
            schema: %{"properties" => %{"a" => %{"type" => "string"}}, "type" => "object"}
          }
        }
      }
    }
  )

  plug(
    Oasis.Plug.HmacAuth,
    signed_headers: "host;x-oasis-body-sha256",
    scheme: "hmac-sha256",
    security: Oasis.Gen.HmacAuthWithBody
  )

  def call(conn, opts) do
    conn |> super(opts) |> Oasis.Gen.PostTestHmacWithBody.call(opts) |> halt()
  end

  defdelegate handle_errors(conn, error), to: Oasis.Gen.PostTestHmacWithBody
end