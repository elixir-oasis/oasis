defmodule Oasis.ControllerTest do
  use ExUnit.Case, async: true
  use Plug.Test

  import Oasis.Controller
  alias Plug.Conn

  defp get_resp_content_type(conn) do
    [header]  = get_resp_header(conn, "content-type")
    header |> String.split(";") |> Enum.fetch!(0)
  end

  describe "text/2" do
    test "sends the content as text" do
      conn = text(conn(:get, "/"), "hello")
      assert conn.resp_body == "hello"
      assert get_resp_content_type(conn) == "text/plain"
      refute conn.halted

      conn = text(conn(:get, "/"), :hello)
      assert conn.resp_body == "hello"
      assert get_resp_content_type(conn) == "text/plain"
      refute conn.halted
    end

    test "allows status injection on connection" do
      conn = conn(:get, "/") |> put_status(401)
      conn = text(conn, :foo_bar)
      assert conn.resp_body == "foo_bar"
      assert conn.status == 401
    end
  end

  describe "html/2" do
    test "sends the content as html" do
      conn = html(conn(:get, "/"), "foobar")
      assert conn.resp_body == "foobar"
      assert conn.status == 200
      assert get_resp_content_type(conn) == "text/html"
      refute conn.halted
    end

    test "allows status injection on connection" do
      conn = conn(:get, "/") |> put_status(401)
      conn = html(conn, "<html>hello</html>")
      assert conn.resp_body == "<html>hello</html>"
      assert conn.status == 401
    end
  end

  describe "json/2" do
    test "encodes content to json" do
      conn = json(conn(:get, "/"), %{ids: [1, 2, 3]})
      assert conn.resp_body == "{\"ids\":[1,2,3]}"
      assert get_resp_content_type(conn) == "application/json"
      refute conn.halted
    end

    test "allows status injection on connection" do
      conn = conn(:get, "/") |> put_status(401)
      conn = json(conn, %{hello: :world})
      assert conn.resp_body == "{\"hello\":\"world\"}"
      assert conn.status == 401
    end

    test "allows content-type injection on connection" do
      conn = conn(:get, "/") |> put_resp_content_type("application/vnd.api+json")
      conn = json(conn, %{"foo" => %{"ids" => [3,2,1]}})
      assert conn.resp_body == "{\"foo\":{\"ids\":[3,2,1]}}"
      assert Conn.get_resp_header(conn, "content-type") ==
               ["application/vnd.api+json; charset=utf-8"]
    end
  end

end
