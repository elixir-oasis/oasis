defmodule Oasis.HTTPServer do
  @moduledoc false

  def start(port) do
    children = [
      Plug.Adapters.Cowboy.child_spec(
        scheme: :http,
        plug: __MODULE__.PlugRouter,
        options: [
          port: port
        ]
      )
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end

defmodule Oasis.HTTPServer.PlugRouter do
  @moduledoc false

  use Oasis.Router

  plug(:match)

  plug(:dispatch)

  get "/hello" do
    send_resp(conn, 200, "world")
  end

  get "/id/:id",
    private: %{
      path_schema: %{
        "id" => %{
          "schema" => %ExJsonSchema.Schema.Root{
            schema: %{"type" => "integer"}
          }
        }
      }
    } do
    conn = fetch_query_params(conn)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(%{"local_var_id" => id, "conn_params" => conn.params}))
  end

  get("/test_query/:id",
    private: %{
      path_schema: %{
        "id" => %{
          "schema" => %ExJsonSchema.Schema.Root{
            schema: %{"type" => "integer"}
          }
        }
      }
    },
    to: Oasis.Gen.Plug.PreTestQuery
  )

  get("/test_header",
    to: Oasis.Gen.Plug.PreTestHeader
  )

  get("/test_cookie",
    to: Oasis.Gen.Plug.PreTestCookie
  )

  post("/test_post_urlencoded",
    to: Oasis.Gen.Plug.PreTestPostUrlencoded
  )

  post("/test_post_multipart",
    to: Oasis.Gen.Plug.PreTestPostMultipart
  )

  post("/test_post_non_validate",
    to: Oasis.Gen.Plug.TestPostNonValidate
  )

  delete("/test_delete",
    to: Oasis.Gen.Plug.PreTestDelete
  )

  get("/bearer_auth",
    to: Oasis.Gen.Plug.PreTestBearerAuth
  )

  post("/sign_bearer_auth",
    to: Oasis.Gen.Plug.PreTestSignBearerAuth
  )

  def handle_errors(conn, %{kind: _kind, reason: reason, stack: _stack}) do
    message = Map.get(reason, :message, "Something went wrong")
    send_resp(conn, conn.status, message)
  end
end
