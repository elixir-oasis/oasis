defmodule Oasis do
  @moduledoc false

  defmodule InvalidSpecError do
    defexception message: "use some invalid specification to generate modules"

    @moduledoc """
    Error raised when use some invalid OpenAPI specification to generate corresponding modules
    """
  end

  defmodule FileNotFoundError do
    defexception message: "failed to open file to generate modules"

    @moduledoc """
    Error raised when use an invalid file path to generate corresponding modules
    """
  end

  defmodule CacheRawBodyReader do
    def read_body(conn, opts) do
      {:ok, body, conn} = Plug.Conn.read_body(conn, opts)
      conn = update_in(conn.assigns[:raw_body], &[body | &1 || []])
      {:ok, body, conn}
    end
  end
end
