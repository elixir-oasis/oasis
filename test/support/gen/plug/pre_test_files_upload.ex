defmodule Oasis.Gen.Plug.PreTestFilesUpload do

  use Oasis.Controller
  use Plug.ErrorHandler

  plug(
    Plug.Parsers,
    parsers: [:multipart],
    pass: ["*/*"]
  )

  plug(
    Oasis.Plug.RequestValidator,
    body_schema: %{
      "content" => %{
        "multipart/form-data" => %{
          "schema" => %ExJsonSchema.Schema.Root{
            schema: %{
              "properties" => %{
                "file" => %{"items" => %{}, "type" => "array"},
                "logo" => %{"type" => "string"},
                "id" => %{"type" => "integer"}
              }
            }
          }
        }
      }
    }
  )

  def call(conn, opts) do
    conn |> super(opts) |> Oasis.Gen.Plug.TestFilesUpload.call(opts) |> halt()
  end

  defdelegate handle_errors(conn, error), to: Oasis.Gen.Plug.TestFilesUpload
end
