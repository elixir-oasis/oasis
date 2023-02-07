defmodule Oasis.Gen.Plug.PreTestPostJSON do
  use Oasis.Controller
  use Plug.ErrorHandler

  plug(
    Plug.Parsers,
    parsers: [:json],
    json_decoder: Jason,
    pass: ["*/*"]
  )

  plug(
    Oasis.Plug.RequestValidator,
    body_schema: %{
      "required" => true,
      "content" => %{
        "application/json" => %{
          "schema" => %ExJsonSchema.Schema.Root{
            schema: %{
              "items" => %{
                "type" => "object",
                "properties" => %{
                  "id" => %{"type" => "integer"},
                  "name" => %{"type" => "string"}
                }
              },
              "type" => "array"
            }
          }
        },
        "application/vnd.api-v1+json" => %{
          "schema" => %ExJsonSchema.Schema.Root{
            schema: %{
              "type" => "integer"
            }
          }
        },
        "application/vnd.api-v2+json" => %{
          "schema" => %ExJsonSchema.Schema.Root{
            schema: %{
              "type" => "number"
            }
          }
        },
        "application/vnd.api-v3+json" => %{
          "schema" => %ExJsonSchema.Schema.Root{
            schema: %{
              "properties" => %{
                "_json" => %{
                  "type" => "object",
                  "properties" => %{
                    "street_name" => %{"type" => "string"},
                    "street_type" => %{"enum" => ["Street", "Avenue", "Boulevard"]},
                    "id" => %{"type" => "integer"}
                  }
                }
              },
              "type" => "object"
            }
          }
        },

      }
    }
  )

  def call(conn, opts) do
    conn |> super(opts) |> Oasis.Gen.Plug.TestPost.call(opts) |> halt()
  end

  defdelegate handle_errors(conn, error), to: Oasis.Gen.Plug.TestPost

end
