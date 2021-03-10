defmodule Oasis.Gen.Plug.PreTestCookie do
  use Plug.Builder
  use Plug.ErrorHandler

  plug(Oasis.Plug.RequestValidator,
    cookie_schema: %{
      "items" => %{
        "required" => true,
        "schema" => %ExJsonSchema.Schema.Root{
          schema: %{"items" => %{"type" => "number"}, "type" => "array"}
        }
      }
    }
  )

  def call(conn, opts) do
    conn |> super(opts) |> Oasis.Gen.Plug.TestCookie.call(opts) |> halt()
  end

  def handle_errors(conn, error) do
    Oasis.Gen.Plug.TestCookie.handle_errors(conn, error)
  end
end
