defmodule Oasis.Gen.Plug.PreTestBearerAuth do
  use Oasis.Controller
  use Plug.ErrorHandler

  import Oasis.Plug.BearerAuth

  plug(Oasis.Plug.RequestValidator,
    query_schema: %{
      "max_age" => %{
        "schema" => %ExJsonSchema.Schema.Root{
          schema: %{"type" => "integer"}
        },
        "required" => false
      }
    }
  )

  plug :bearer_auth,
    security: Oasis.Gen.BearerAuth,
    key_to_assigns: :id

  def call(conn, opts) do
    conn |> super(conn) |> Oasis.Gen.Plug.TestBearerAuth.call(opts) |> halt()
  end

  def handle_errors(conn, error) do
    Oasis.Gen.Plug.TestBearerAuth.handle_errors(conn, error)
  end
end
