defmodule Mix.Tasks.Oas.Plug.Init do
  use Mix.Task

  @shortdoc "Generates Plug modules from OpenAPI Specification"
  def run(_args) do
    IO.puts("Generates Plug modules from OAS")
  end
end
