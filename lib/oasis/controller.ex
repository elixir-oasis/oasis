defmodule Oasis.Controller do
  @moduledoc ~S"""
  Base on `Plug.Builder`, this module can be `use`-d into a module in order to build a plug pipeline:

      defmodule MyApp.HelloController do
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

  And provide some common functionality for easily use, this realization comes from
  [Phoenix.Controller](https://hexdocs.pm/phoenix/Phoenix.Controller.html)
  """
  import Plug.Conn

  defmacro __using__(_opts) do
    quote location: :keep do
      import Oasis.Controller

      use Plug.Builder
    end
  end

  @doc """
  Returns the router module as an atom, raises if unavailable.
  """
  @spec router_module(Plug.Conn.t) :: atom()
  def router_module(conn), do: conn.private.oasis_router

  @doc """
  Sends text response.

  ## Examples
  
      iex> text(conn, "hello")

      iex> text(conn, :implements_to_string)

  """
  @spec text(Plug.Conn.t(), String.Chars.t()) :: Plug.Conn.t()
  def text(conn, data) do
    send_resp(conn, conn.status || 200, "text/plain", to_string(data))
  end

  @doc """
  Sends html response.

  ## Examples

      iex> html(conn, "<html>...</html>")

  """
  @spec html(Plug.Conn.t(), iodata()) :: Plug.Conn.t()
  def html(conn, data) do
    send_resp(conn, conn.status || 200, "text/html", data)
  end

  @doc """
  Sends JSON response.

  It uses `Jason` to encode the input as an iodata data.
  
  ## Examples

      iex> json(conn, %{id: 1})

  """
  @spec json(Plug.Conn.t(), term) :: Plug.Conn.t()
  def json(conn, data) do
    response = Jason.encode_to_iodata!(data)
    send_resp(conn, conn.status || 200, "application/json", response)
  end

  defp send_resp(conn, default_status, default_content_type, body) do
    conn
    |> ensure_resp_content_type(default_content_type)
    |> send_resp(conn.status || default_status, body)
  end

  defp ensure_resp_content_type(%Plug.Conn{resp_headers: resp_headers} = conn, content_type) do
    if List.keyfind(resp_headers, "content-type", 0) do
      conn
    else
      content_type = content_type <> "; charset=utf-8"
      %Plug.Conn{conn | resp_headers: [{"content-type", content_type} | resp_headers]}
    end
  end
end
