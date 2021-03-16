defmodule Mix.Tasks.Oas.Gen.Plug do
  use Mix.Task

  @switches [file: :string, router: :string, name_space: :string, body_reader: :string]

  @shortdoc "Generates Router and Plug modules from OpenAPI Specification"
  def run(args) do
    if Mix.Project.umbrella?() do
      Mix.raise "mix oas.gen.plug can only be run inside an application directory"
    end

    Mix.shell().info("Generates Router and Plug modules from OAS")

    paths = Mix.Oasis.generator_paths()

    files = build(args)

    Mix.Oasis.copy_from(paths, "priv/templates/oas.gen.plug", files)
  end

  defp build(args) do
    opts = parse_opts(args)

    %ExJsonSchema.Schema.Root{schema: schema} = Oasis.Spec.read(opts[:file])

    opts = Keyword.take(opts, [:router, :name_space, :body_reader])

    Mix.Oasis.new(schema, opts)
  end

  defp parse_opts(args) do
    {opts, _, _} = OptionParser.parse(args, switches: @switches)
    validate_opts!(opts)
  end

  defp validate_opts!(opts) do
    oas_file_path = Keyword.get(opts, :file)

    if oas_file_path == nil do
      raise_with_help("Expected input `--file` option to be a valid path to a yaml/json file")
    else
      if File.exists?(oas_file_path) do
        opts
      else
        raise_with_help("Could not find the file in `#{oas_file_path}` path")
      end
    end
  end

  defp raise_with_help(msg) do
    Mix.raise("""
    #{msg}

    For example:

        mix oas.gen.plug --file path/to/file.yaml
        mix oas.gen.plug --file path/to/file.json
        mix oas.gen.plug --file path/to/file.yml --name-space Test --router Router

    By default the `--name-space` is "Oasis.Gen", and by default
    the `--router` is "Router", these two options are optional.
    """)
  end
end
