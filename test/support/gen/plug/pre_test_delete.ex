defmodule Oasis.Gen.Plug.PreTestDelete do
  use Oasis.Controller
  use Plug.ErrorHandler

  plug(
    Plug.Parsers,
    parsers: [:urlencoded],
    pass: ["*/*"]
  )

  plug(
    Oasis.Plug.RequestValidator,
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
    conn |> super(opts) |> Oasis.Gen.Plug.TestDelete.call(opts) |> halt()
  end

  defdelegate handle_errors(conn, error), to: Oasis.Gen.Plug.TestDelete

end
