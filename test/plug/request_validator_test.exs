defmodule Oasis.Plug.RequestValidatorTest do
  use ExUnit.Case, asysnc: false
  use Plug.Test

  alias Oasis.Plug.RequestValidator

  @schema1 %ExJsonSchema.Schema.Root{
    schema: %{
      "properties" => %{
        "name" => %{"type" => "string"},
        "tag" => %{"type" => "integer"}
      },
      "required" => ["name", "tag"],
      "type" => "object"
    }
  }

  describe "with charset in send request" do
    test "content type application/json" do
      body_schema = %{
        "content" => %{
          "application/json" => %{
            "schema" => @schema1
          }
        },
        "required" => true
      }

      assert_raise Oasis.BadRequestError, ~r/Failed to convert parameter/, fn ->
        conn = 
          conn(:post, "/req_validator", %{"name"=> "test_name", "tag" => "a"})
          |> put_req_header("content-type", "Application/json; charset=utf-8")
        RequestValidator.call(conn, body_schema: body_schema)
      end

      conn =
        conn(:post, "/req_validator", %{"name"=> "test_name", "tag" => "1"})
        |> put_req_header("content-type", "Application/json; charset=utf-8")

      conn = RequestValidator.call(conn, body_schema: body_schema)
      body_params = conn.body_params
      params = conn.params
      assert body_params == params
      assert body_params["tag"] == 1 and body_params["name"] == "test_name"
    end

    test "content type text/plain" do
      body_schema = %{
        "content" => %{
          "text/plain" => %{
            "schema" => @schema1
          }
        },
        "required" => true
      }

      assert_raise Oasis.BadRequestError, ~r/Failed to convert parameter/, fn ->
        conn = 
          conn(:post, "/req_validator", %{"name"=> "test_name", "tag" => "a"})
          |> put_req_header("content-type", "tExt/PlAin; charset=utf-8")
        RequestValidator.call(conn, body_schema: body_schema)
      end

      conn =
        conn(:post, "/req_validator", %{"name"=> "test_name", "tag" => "-1"})
        |> put_req_header("content-type", "text/plain; charset=utf-8")

      conn = RequestValidator.call(conn, body_schema: body_schema)
      body_params = conn.body_params
      params = conn.params
      assert body_params == params
      assert body_params["tag"] == -1 and body_params["name"] == "test_name"
    end

    test "content type application/x-www-form-urlencoded" do
      body_schema = %{
        "content" => %{
          "application/x-www-form-urlencoded" => %{
            "schema" => @schema1
          }
        },
        "required" => true
      }

      assert_raise Oasis.BadRequestError, ~r/Failed to convert parameter/, fn ->
        conn = 
          conn(:post, "/req_validator", %{"name"=> "test_name", "tag" => "a"})
          |> put_req_header("content-type", "application/x-www-form-urlencoded; charset=utf-8")
        RequestValidator.call(conn, body_schema: body_schema)
      end

      assert_raise Oasis.BadRequestError, ~r/Failed to convert parameter/, fn ->
        conn =
          conn(:post, "/req_validator", %{"name"=> "test_name2", "tag" => "100.0"})
          |> put_req_header("content-type", "application/x-www-form-urlencoded; charset=utf-8")
        RequestValidator.call(conn, body_schema: body_schema)
      end

      conn =
        conn(:post, "/req_validator", %{"name"=> "test_name2", "tag" => "1000"})
        |> put_req_header("content-type", "application/x-www-form-urlencoded; charset=utf-8")

      conn = RequestValidator.call(conn, body_schema: body_schema)
      body_params = conn.body_params
      params = conn.params
      assert body_params == params
      assert body_params["tag"] == 1000 and body_params["name"] == "test_name2"
    end
  end

end
