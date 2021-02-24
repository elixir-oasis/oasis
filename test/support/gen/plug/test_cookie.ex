defmodule Oasis.Gen.Plug.TestCookie do
  import Plug.Conn

  @behaviour Plug

  def init(opts), do: opts

  def call(conn, _opts) do
    conn = put_in(conn.secret_key_base, "secret")

    conn = fetch_cookies(conn, signed: ~w(testcookie1 testcookie2))

    conn
    |> put_resp_content_type("application/json")
    |> put_resp_cookie("testcookie1", %{name: "testname"}, sign: true)
    |> put_resp_cookie("testcookie2", 1001, sign: true)
    |> send_resp(200, Jason.encode!(%{"req_cookies" => conn.req_cookies}))
  end

  def handle_errors(conn, %{kind: _kind, reason: reason, stack: _stack}) do
    message = Map.get(reason, :message, "Something went wrong")
    send_resp(conn, conn.status, message)
  end
end
