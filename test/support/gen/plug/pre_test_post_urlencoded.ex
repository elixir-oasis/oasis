defmodule Oasis.Gen.Plug.PreTestPostUrlencoded do
  use Oasis.Controller
  use Plug.ErrorHandler

  plug(
    Plug.Parsers,
    parsers: [:urlencoded],
    pass: ["*/*"],
    # may support an option to off/on this.
    body_reader: {Oasis.CacheRawBodyReader, :read_body, []}
  )

  plug(
    Oasis.Plug.RequestValidator,
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
    conn |> super(opts) |> Oasis.Gen.Plug.TestPost.call(opts) |> halt()
  end

  defdelegate handle_errors(conn, error), to: Oasis.Gen.Plug.TestPost

end
