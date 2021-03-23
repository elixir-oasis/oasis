defmodule <%= inspect context.module_name %> do
  # NOTICE: Please DO NOT write any business code in this module, since it will always be overwrote when
  # run the corresponding mix task command to the OpenAPI Specification.
  use Oasis.Controller
  use Plug.ErrorHandler
  
  <%= context.plug_parsers %>

  <%= context.request_validator %>

  def call(conn, opts) do
    conn |> super(opts) |> <%= inspect context.plug_module %>.call(opts) |> halt()
  end

  def handle_errors(conn, error) do
    <%= inspect context.plug_module %>.handle_errors(conn, error)
  end

end
