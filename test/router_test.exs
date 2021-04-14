defmodule Oasis.RouterTest do
  defmodule Sample do
    use Oasis.Router

    plug(:match)

    plug(:dispatch)

    get "/1/:bar" do
      resp(conn, 200, inspect(bar))
    end

    match "/foo/:bar",
      via: [:get],
      private: %{
        path_schema: %{
          "id" => %{
            "schema" => %ExJsonSchema.Schema.Root{
              schema: %{"type" => "integer"}
            }
          }
        }
      } do
      resp(conn, 200, Jason.encode!(%{bar: bar}))
    end

    head "/head" do
      resp(conn, 200, "")
    end

    patch "/patch" do
      resp(conn, 200, "")
    end

    options "/options" do
      resp(conn, 200, "")
    end

    put "/put" do
      resp(conn, 200, "")
    end

    get "/get/:id",
      private: %{
        path_schema: %{
          "id" => %{
            "schema" => %ExJsonSchema.Schema.Root{
              schema: %{"type" => "integer"}
            }
          }
        }
      } do
      resp(conn, 200, Jason.encode!(%{id: id}))
    end

    post "/post/:page_id",
      private: %{
        path_schema: %{
          "page_id" => %{
            "schema" => %ExJsonSchema.Schema.Root{
              schema: %{"type" => "integer"}
            }
          }
        }
      } do
      resp(conn, 200, Jason.encode!(%{page_id: page_id}))
    end

    delete "/delete/:user_id/:group_id",
      private: %{
        path_schema: %{
          "user_id" => %{
            "schema" => %ExJsonSchema.Schema.Root{
              schema: %{"type" => "integer"}
            }
          },
          "group_id" => %{
            "schema" => %ExJsonSchema.Schema.Root{
              schema: %{"type" => "string"}
            }
          }
        }
      } do
      resp(conn, 200, Jason.encode!(%{user_id: user_id, group_id: group_id}))
    end

  end

  use ExUnit.Case, async: true
  use Plug.Test

  test "declare and call HEAD request" do
    conn = call(Sample, conn(:head, "/head"))
    assert conn.status == 200
  end

  test "declare and call OPTIONS request" do
    conn = call(Sample, conn(:options, "/options"))
    assert conn.status == 200
  end

  test "declare and call PATCH request" do
    conn = call(Sample, conn(:patch, "/patch"))
    assert conn.status == 200
  end

  test "declare and call PUT request" do
    conn = call(Sample, conn(:put, "/put"))
    assert conn.status == 200
  end

  test "match_path/1" do
    conn = call(Sample, conn(:get, "/1/abc"))
    assert Plug.Router.match_path(conn) == "/1/:bar"
  end

  test "parse and validation are not working in macro match/2 and match/3" do
    conn = call(Sample, conn(:get, "/foo/2"))
    assert conn.params["bar"] == "2"
    assert conn.path_params["bar"] == "2"
    assert Jason.decode!(conn.resp_body) == %{"bar" => "2"}
  end

  test "parse and assigns path params to conn params and path_params in GET request" do
    conn = call(Sample, conn(:get, "/get/100"))
    assert conn.params["id"] == 100
    assert conn.path_params["id"] == 100
    assert Jason.decode!(conn.resp_body) == %{"id" => 100}
  end

  test "parse and assigns path params to conn params and path_params in POST request" do
    conn = call(Sample, conn(:post, "/post/1"))
    assert conn.params["page_id"] == 1
    assert conn.path_params["page_id"] == 1
    assert Jason.decode!(conn.resp_body) == %{"page_id" => 1}
  end

  test "parse and assigns path params to conn params and path_params in DELETE request" do
    conn = call(Sample, conn(:delete, "/delete/01/abcdef"))
    assert conn.params["user_id"] == 1
    assert conn.params["group_id"] == "abcdef"
    assert conn.path_params["user_id"] == 1
    assert conn.path_params["group_id"] == "abcdef"
    assert Jason.decode!(conn.resp_body) == %{"user_id" => 1, "group_id" => "abcdef"}
  end

  test "handler_errors/2 in generated plug module" do
    conn = conn(:get, "/test_header")
    assert_raise Plug.Conn.WrapperError, ~s/** (Oasis.BadRequestError) Missing required parameter/, fn ->
      call(Oasis.HTTPServer.PlugRouter, conn)
    end

    conn = put_req_header(conn, "items", "[1,2,3]")
    conn = call(Oasis.HTTPServer.PlugRouter, conn)
    assert conn.req_headers == [{"items", [1, 2, 3]}]

    conn = conn(:get, "/test_header?raise=true") |> put_req_header("items", "[0]")
    assert_raise Plug.Conn.WrapperError, "** (RuntimeError) oops", fn ->
      call(Oasis.HTTPServer.PlugRouter, conn)
    end
  end

  defp call(mod, conn) do
    mod.call(conn, [])
  end
end
