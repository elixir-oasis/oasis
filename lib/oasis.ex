defmodule Oasis do
  @moduledoc false

  defmodule InvalidSpecError do
    defexception message: "use some invalid specification to generate modules"

    @moduledoc """
    Error raised when use some invalid OpenAPI specification to generate corresponding modules.
    """
  end

  defmodule FileNotFoundError do
    defexception message: "failed to open file to generate modules"

    @moduledoc """
    Error raised when use an invalid file path to generate corresponding modules.
    """
  end

  defmodule BadRequestError do
    @moduledoc """
    Error raised when some reason could not process the request due to client error.
    """
    defexception message: "invalid request", use_in: nil, param_name: nil, error: nil, plug_status: 400

    defmodule Invalid do
      @moduledoc """
      This error is used to indicate could not parse a parameter into the type due to client error.
      """
      defstruct [:value]
    end

    defmodule Required do
      @moduledoc """
      This error is used to indicate there missing a required parameter due to client error.
      """
      defstruct([])
    end

    defmodule JsonSchemaValidationFailed do
      @moduledoc """
      This error is used to indicate could not pass the validation of the defined json schema.

      This module is an equivalent replacement to `ExJsonSchema.Validator.Error`, we could see more detailed information
      in the `:error` field be with `"ExJsonSchema.Validator.Error.*"` modules.
      """
      defstruct [:error, :path]
    end

    defmodule InvalidToken do
      @moduledoc """
      This error is used to indicate the provided token is expired, revoked, malformed, or invalid.
      """
      defstruct([])
    end

  end

  defmodule CacheRawBodyReader do
    @moduledoc false

    def read_body(conn, opts) do
      {:ok, body, conn} = Plug.Conn.read_body(conn, opts)
      conn = update_in(conn.assigns[:raw_body], &[body | &1 || []])
      {:ok, body, conn}
    end
  end

end
