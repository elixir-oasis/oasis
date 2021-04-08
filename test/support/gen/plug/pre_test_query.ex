defmodule Oasis.Gen.Plug.PreTestQuery do
  use Oasis.Controller
  use Plug.ErrorHandler

  plug(
    Oasis.Plug.RequestValidator,
    query_schema: %{
      "profile" => %{
        "content" => %{
          "application/json" => %{
            "schema" => %ExJsonSchema.Schema.Root{
              schema: %{
                "properties" => %{
                  "name" => %{"type" => "string"},
                  "tag" => %{"type" => "integer"}
                },
                "required" => ["name", "tag"],
                "type" => "object"
              }
            }
          }
        },
        "required" => false
      },
      "lang" => %{
        "schema" => %ExJsonSchema.Schema.Root{
          schema: %{"type" => "integer", "minimum" => 10, "maximum" => 20}
        },
        "required" => true
      },
      "all" => %{
        "schema" => %ExJsonSchema.Schema.Root{
          schema: %{"type" => "boolean"}
        },
        "required" => false
      }
    }
  )

  def call(conn, opts) do
    conn |> super(opts) |> Oasis.Gen.Plug.TestQuery.call(opts) |> halt()
  end

  defdelegate handle_errors(conn, error), to: Oasis.Gen.Plug.TestQuery

end
