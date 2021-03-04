defmodule Oasis.Gen.Plug.PreTestDelete do
  use Plug.Builder
  use Plug.ErrorHandler

  plug(Plug.Parsers,
    parsers: [:urlencoded],
    pass: ["*/*"]
  )

  plug(Oasis.Plug.RequestValidator,
    query_schema: %{
      "relation_ids" => %{
        "schema" => %ExJsonSchema.Schema.Root{
          schema: %{
            "type" => "array",
            "items" => %{"type" => "string"}
          }
        },
        "required" => false
      },
      "id" => %{
        "schema" => %ExJsonSchema.Schema.Root{
          schema: %{"type" => "integer"}
        },
        "required" => true
      }
    }
  )

  def call(conn, opts) do
    conn |> super(opts) |> Oasis.Gen.Plug.TestDelete.call(opts)
  end

  def handle_errors(conn, error) do
    Oasis.Gen.Plug.TestDelete.handle_errors(conn, error)
  end
end
