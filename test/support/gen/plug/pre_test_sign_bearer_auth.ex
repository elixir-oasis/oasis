defmodule Oasis.Gen.Plug.PreTestSignBearerAuth do
  use Oasis.Controller
  use Plug.ErrorHandler

  plug(Plug.Parsers,
    parsers: [:urlencoded],
    pass: ["*/*"]
  )

  plug(Oasis.Plug.RequestValidator,
    body_schema: %{
      "required" => true,
      "content" => %{
        "application/x-www-form-urlencoded" => %{
          "schema" => %ExJsonSchema.Schema.Root{
            schema: %{
              "properties" => %{
                "username" => %{"type" => "string"},
                "password" => %{"type" => "string"},
                "max_age" => %{"type" => "integer"}
              },
              "required" => ["username", "password"],
              "type" => "object"
            }
          }
        }
      }
    }
  )

  def call(conn, opts) do
    conn |> super(conn) |> Oasis.Gen.Plug.TestSignBearerAuth.call(opts) |> halt()
  end

  def handle_errors(conn, error) do
    Oasis.Gen.Plug.TestSignBearerAuth.handle_errors(conn, error)
  end
end
