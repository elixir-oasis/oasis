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

      inspect_as_struct(pruned, inspect_atom_2_literal(module), opts)
    end

    if Code.ensure_loaded?(Macro) and function_exported?(Macro, :inspect_atom, 2) do
      # above elixir 1.14
      defp inspect_atom_2_literal(module), do: Macro.inspect_atom(:literal, module)
    end

    if Code.ensure_loaded?(Code.Identifier) and
         function_exported?(Code.Identifier, :inspect_as_atom, 1) do
      # below elixir 1.14
      defp inspect_atom_2_literal(module), do: Code.Identifier.inspect_as_atom(module)
    end

    if Code.ensure_loaded?(Inspect.Map) and function_exported?(Inspect.Map, :inspect, 4) do
      # above elixir 1.14
      defp inspect_as_struct(map, struct_module_name, opts) do
        # struct of `infos` refers to:
        # https://github.com/elixir-lang/elixir/blob/v1.14/lib/elixir/lib/inspect.ex#L594
        infos = map |> Map.keys() |> Enum.map(&%{field: &1})
        Inspect.Map.inspect(map, struct_module_name, infos, opts)
      end
    end

    if Code.ensure_loaded?(Inspect.Map) and function_exported?(Inspect.Map, :inspect, 3) do
      # below elixir 1.14
      defp inspect_as_struct(map, struct_module_name, opts),
        do: Inspect.Map.inspect(map, struct_module_name, opts)
    end
  end

  def new(%{"paths" => paths} = spec, opts) when is_map(paths) do
    Mix.Oasis.Router.generate_files_by_paths_spec(generator_paths(), spec, opts)
  end

  def new(spec, _opts) do
    raise "could not find any paths defined in #{inspect(spec)}"
  end

  def name_space(nil) do
    {
      "Oasis.Gen",
      "lib/oasis/gen"
    }
  end

  def name_space(name_space) when is_bitstring(name_space) do
    splited = split_module_alias(name_space)

    path = module_alias_to_path(splited)

    {
      conact_module_alias(splited),
      Path.join(["lib", path])
    }
  end

  defp split_module_alias(str) do
    str |> String.split(".") |> Enum.filter(&(&1 != ""))
  end

  defp module_alias_to_path(aliases) when is_list(aliases) do
    aliases
    |> Enum.map(&Recase.to_snake(&1))
    |> Enum.join("/")
  end

  def module_alias(name) when is_bitstring(name) do
    process_module_alias(name)
  end

  def module_alias(%{operation_id: operation_id}) when operation_id != nil do
    process_module_alias(operation_id)
  end

  def module_alias(%{http_verb: http_verb, url: url}) do
    uri = URI.parse(url)
    url = uri.path |> String.replace(["/", ":", "."], "-")
    last_alias = "#{http_verb}#{url}"
    module_alias_and_file_path(last_alias, [], [last_alias])
  end

  defp process_module_alias(name) do
    splited = split_module_alias(name)

    {last_alias, prefix_aliases} = List.pop_at(splited, -1)

    if last_alias == nil do
      raise "input invalid module alias: `#{name}`"
    end

    module_alias_and_file_path(last_alias, prefix_aliases, splited)
  end

  defp module_alias_and_file_path(last_alias, [], aliases) do
    {
      conact_module_alias(aliases),
      "#{Recase.to_snake(last_alias)}.ex"
    }
  end

  defp module_alias_and_file_path(last_alias, prefix_aliases, aliases) do
    path = module_alias_to_path(prefix_aliases)

    {
      conact_module_alias(aliases),
      "#{path}/#{Recase.to_snake(last_alias)}.ex"
    }
  end

  defp conact_module_alias(aliases) do
    aliases
    |> Enum.map(&Recase.to_pascal(&1))
    |> Enum.join(".")
  end

  def copy_from(apps, source_dir, mapping, opts \\ []) when is_list(mapping) do
    roots = Enum.map(apps, &to_app_source(&1, source_dir))
    create_file_opts = Keyword.take(opts, [:force, :quiet])

    for {format, target, source_file_path, module_name, binding} <- mapping do
      source =
        Enum.find_value(roots, fn root ->
          source = Path.join(root, source_file_path)
          if File.exists?(source), do: source
        end) || raise "could not find #{source_file_path} in any of the sources"

      binding = Map.put(binding, :module_name, module_name)
      file_contents = EEx.eval_file(source, context: binding) |> Code.format_string!()

      case format do
        :eex ->
          Mix.Generator.create_file(target, file_contents, create_file_opts)

        :new_eex ->
          if File.exists?(target) do
            :ok
          else
            Mix.Generator.create_file(target, file_contents, create_file_opts)
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
