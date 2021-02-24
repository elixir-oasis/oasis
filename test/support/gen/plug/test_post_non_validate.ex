defmodule Oasis.Gen.Plug.TestPostNonValidate do
  use Plug.Builder

  plug(Plug.Parsers,
    parsers: [:urlencoded],
    pass: ["*/*"]
  )

  def call(conn, opts) do
    conn = super(conn, opts)
    resp_body = Jason.encode!(%{"body_params" => conn.body_params})
    send_resp(conn, 200, resp_body)
  end

end
