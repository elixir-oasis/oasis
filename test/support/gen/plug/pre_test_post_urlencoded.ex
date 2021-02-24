defmodule Oasis.Gen.Plug.PreTestPostUrlencoded do
  use Plug.Builder
  use Plug.ErrorHandler

  plug(Plug.Parsers,
    parsers: [:urlencoded],
    pass: ["*/*"],
    body_reader: {Oasis.CacheRawBodyReader, :read_body, []} # may support an option to off/on this.
  )

  plug(Oasis.Plug.RequestValidator,
    body_schema: %{
      "required" => true,
      "content" => %{
        "application/x-www-form-urlencoded" => %{
          "schema" => %ExJsonSchema.Schema.Root{
            schema: %{
              "properties" => %{
                "name" => %{"type" => "string"},
                "fav_number" => %{"type" => "integer", "minimum" => 1, "maximum" => 3}
              },
              "required" => ["name", "fav_number"],
              "type" => "object"
            }
          }
        }
      }
    }
  )

  def call(conn, opts) do
    conn |> super(opts) |> Oasis.Gen.Plug.TestPost.call(opts)
  end

  def handle_errors(conn, error) do
    Oasis.Gen.Plug.TestPost.handle_errors(conn, error)
  end
end
