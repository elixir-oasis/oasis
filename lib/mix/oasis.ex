defmodule Mix.Oasis do
  @moduledoc false

  defimpl Inspect, for: ExJsonSchema.Schema.Root do
    @default %ExJsonSchema.Schema.Root{}

    def inspect(%module{} = root, opts) do
      # simplify `ExJsonSchema.Schema.Root` struct to inspect when generate `Oasis.Plug.RequestValidator` plug
      # with :body_schema, :cookie_schema, :header_schema, :query_schema and :path_schema option(s)

      pruned = Map.drop(root, [:__struct__, :__exception__])

      pruned =
        Enum.reduce(pruned, pruned, fn {key, value}, acc ->
          default_value = Map.get(@default, key)

          if value == default_value do
            Map.drop(acc, [key])
          else
            acc
          end
        end)

      Inspect.Map.inspect(pruned, Code.Identifier.inspect_as_atom(module), opts)
    end
  end

  def new(%{"paths" => paths} = _content, opts) do
    Mix.Oasis.Router.generate_files_by_paths_spec(generator_paths(), paths, opts)
  end

  def new(content, _opts) do
    raise "could not find any paths defined in #{inspect(content)}"
  end

  def name_space(nil) do
    {
      Path.join(["lib", "oasis", "gen"]),
      default_name_space()
    }
  end

  def name_space(name_space) when is_bitstring(name_space) do
    target_dir =
      name_space
      |> String.split(".")
      |> Enum.filter(&(&1 != ""))
      |> Enum.map(&Recase.to_snake(&1))
      |> Enum.join("/")
      |> String.downcase()

    {
      Path.join(["lib", target_dir]),
      Module.concat([name_space])
    }
  end

  defp default_name_space(), do: Oasis.Gen

  def module_name(name) when is_bitstring(name) do
    name |> Recase.to_pascal() |> module_to_file_name()
  end

  def module_name(%{operation_id: operation_id}) when operation_id != nil do
    operation_id |> Recase.to_pascal() |> module_to_file_name()
  end

  def module_name(%{http_verb: http_verb, url: url}) do
    uri = URI.parse(url)
    url = uri.path |> String.replace(["/", ":", "."], "-")
    Recase.to_pascal("#{http_verb}#{url}") |> module_to_file_name()
  end

  defp module_to_file_name(module_name) do
    {
      module_name,
      "#{Recase.to_snake(module_name)}.ex"
    }
  end

  def copy_from(apps, source_dir, mapping) when is_list(mapping) do
    roots = Enum.map(apps, &to_app_source(&1, source_dir))

    for {format, target, source_file_path, module_name, binding} <- mapping do
      source =
        Enum.find_value(roots, fn root ->
          source = Path.join(root, source_file_path)
          if File.exists?(source), do: source
        end) || raise "could not find #{source_file_path} in any of the sources"

      binding = Map.put(binding, :module_name, module_name)

      case format do
        :eex ->
          Mix.Generator.create_file(
            target,
            EEx.eval_file(source, context: binding) |> Code.format_string!()
          )

        :new_eex ->
          if File.exists?(target) do
            :ok
          else
            Mix.Generator.create_file(
              target,
              EEx.eval_file(source, context: binding) |> Code.format_string!()
            )
          end
      end
    end
  end

  def generator_paths() do
    [".", :oasis]
  end

  def eval_from(apps, source_file_path, binding) do
    sources = Enum.map(apps, &to_app_source(&1, source_file_path))

    content =
      Enum.find_value(sources, fn source ->
        File.exists?(source) && File.read!(source)
      end) || raise "could not find #{source_file_path} in any of the sources"

    EEx.eval_string(content, binding)
  end

  defp to_app_source(path, source_dir) when is_binary(path),
    do: Path.join(path, source_dir)

  defp to_app_source(app, source_dir) when is_atom(app),
    do: Application.app_dir(app, source_dir)
end
