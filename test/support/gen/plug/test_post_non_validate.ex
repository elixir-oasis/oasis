defmodule Oasis.Gen.Plug.TestPostNonValidate do
  use Oasis.Controller

  plug(Plug.Parsers,
    parsers: [:urlencoded],
    pass: ["*/*"]
  )

  def call(conn, opts) do
    conn = super(conn, opts)
    json(conn, %{"body_params" => conn.body_params})
  end
end
