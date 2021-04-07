defmodule Oasis.Gen.Plug.TestSignBearerAuth do
  use Oasis.Controller

  def init(opts), do: opts

  @match [
    username: "a",
    password: "123",
    id: "abcdef"
  ]
  
  def call(conn, _opts) do
    valid_username? = Plug.Crypto.secure_compare(@match[:username], Map.get(conn.body_params, "username"))
    valid_password? = Plug.Crypto.secure_compare(@match[:password], Map.get(conn.body_params, "password"))
    if valid_username? and valid_password? do
      max_age = Map.get(conn.body_params, "max_age")
      crypto =
        if max_age != nil do
          Oasis.Gen.BearerAuth.crypto_config(conn, [max_age: max_age]) 
        else
          Oasis.Gen.BearerAuth.crypto_config(conn)
        end

      token = Oasis.Token.sign(crypto, @match[:id])
      json(conn, %{"token" => token, "expires_in" => crypto.max_age})
    else
      send_resp(conn, 401, "Unauthorized")
    end
  end

  def handle_errors(conn, %{kind: _kind, reason: reason, stack: _stack}) do
    message = Map.get(reason, :message, "Something went wrong")
    send_resp(conn, conn.status, message)
  end
end
