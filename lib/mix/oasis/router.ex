defmodule Mix.Oasis.Router do
  @moduledoc false

  defstruct [
    :http_verb,
    :path_schema,
    :body_schema,
    :header_schema,
    :cookie_schema,
    :query_schema,
    :url,
    :operation_id,
    :name_space,
    :pre_plug_module,
    :plug_module,
    :request_validator,
    :plug_parsers
  ]

  @check_parameter_fields [
    "query",
    "cookie",
    "header",
    "path"
  ]

  def generate_files_by_paths_spec(apps, paths_spec, opts) when is_map(paths_spec) do
    opts = put_opts(paths_spec, opts)

    {plug_files, routers} = generate_plug_files(apps, paths_spec, opts)

    router_file = generate_router_file(routers, opts)

    [router_file | plug_files]
  end

  defp put_opts(paths_spec, opts) do
    # Set the global :name_space use the input option from command line if exists,
    # or use the Paths Object's extension "x-oasis-name-space" field if exists.
    name_space = opts[:name_space] || Map.get(paths_spec, "x-oasis-name-space")

    # Set the :router use the input option from command line if exists,
    # or use the Paths Object's extension "x-oasis-router" field if exists.
    router = opts[:router] || Map.get(paths_spec, "x-oasis-router")

    opts
    |> Keyword.put(:name_space, name_space)
    |> Keyword.put(:router, router)
  end

  defp generate_plug_files(apps, paths_spec, opts) do
    paths_spec
    |> Map.keys()
    |> Enum.reduce({[], []}, fn url, acc ->
      iterate_paths_spec_by_url(apps, paths_spec, url, acc, opts)
    end)
  end

  defp iterate_paths_spec_by_url(
         apps,
         paths_spec,
         "/" <> _ = url,
         {plug_files_acc, routers_acc},
         opts
       ) do
    # `paths_spec` may contain extended object starts with `x-oasis-`,
    # assume a value starts with "/" is a proper url expression.
    {plug_files, routers} =
      paths_spec
      |> Map.get(url, %{})
      |> Map.take(Oasis.Spec.Path.supported_http_verbs())
      |> Enum.reduce({[], []}, fn {http_verb, operation}, {plug_files_to_url, routers_to_url} ->
        {plug_files, router} = new(apps, url, http_verb, operation, opts)

        {
          plug_files ++ plug_files_to_url,
          [router | routers_to_url]
        }
      end)

    {
      plug_files ++ plug_files_acc,
      routers ++ routers_acc
    }
  end

  defp iterate_paths_spec_by_url(_apps, _paths_spec, _url, acc, _opts), do: acc

  defp generate_router_file(routers, opts) do
    {name_space, dir} = Mix.Oasis.name_space(opts[:name_space])

    module_name = Keyword.get(opts, :router) || "Router"
    {module_name, file_name} = Mix.Oasis.module_alias(module_name)

    target = Path.join([dir, file_name])

    routers = Enum.sort(routers, &(&1.url < &2.url))

    {:eex, target, "router.ex", Module.concat([name_space, module_name]), %{routers: routers}}
  end

  defp new(apps, url, http_verb, operation, opts) do
    router =
      Map.merge(
        %__MODULE__{
          http_verb: http_verb,
          url: url
        },
        build_operation(operation, opts)
      )

    build_files_to_generate(apps, router)
  end

  defp build_operation(operation, opts) do
    operation
    |> step1_merge_parameters()
    |> step2_merge_request_body()
    |> step3_merge_others(opts)
  end

  defp step1_merge_parameters(%{"parameters" => parameters} = operation) do
    parameter_schemas =
      @check_parameter_fields
      |> Enum.reduce(%{}, fn location, acc ->
        parameters_to_location = Map.get(parameters, location)

        params_to_schema = group_schemas_by_location(location, parameters_to_location)

        to_schema_opt(params_to_schema, location, acc)
      end)

    {parameter_schemas, operation}
  end

  defp step1_merge_parameters(operation), do: {%{}, operation}

  defp step2_merge_request_body(
         {acc, %{"requestBody" => %{"content" => content} = request_body} = operation}
       )
       when is_map(content) do
    content =
      Enum.reduce(content, %{}, fn {content_type, media}, acc ->
        schema = Map.get(media, "schema")

        if schema != nil do
          Map.put(acc, content_type, %ExJsonSchema.Schema.Root{schema: schema})
        else
          acc
        end
      end)

    if content == %{} do
      # skip if no "schema" defined in Media Type Object.
      {acc, operation}
    else
      body_schema = put_required_if_exists(request_body, %{"content" => content})
      {
        Map.put(acc, :body_schema, body_schema),
        operation
      }
    end
  end

  defp step2_merge_request_body({acc, operation}), do: {acc, operation}

  defp put_required_if_exists(%{"required" => required}, map) when is_boolean(required) and is_map(map) do
    Map.put(map, "required", required)
  end
  defp put_required_if_exists(_, map), do: map

  defp group_schemas_by_location(location, parameters)
       when location in @check_parameter_fields and is_list(parameters) do
    Enum.reduce(parameters, %{}, fn param, acc ->
      map_parameter(param, acc)
    end)
  end

  defp group_schemas_by_location(_location, _parameters), do: nil

  defp map_parameter(%{"name" => name, "schema" => schema} = parameter, acc) do
    parameter = put_required_if_exists(parameter, %{"schema" => %ExJsonSchema.Schema.Root{schema: schema}})

    Map.merge(acc, %{name => parameter})
  end

  defp map_parameter(_, acc), do: acc

  defp to_schema_opt(nil, _, acc), do: acc

  defp to_schema_opt(params, _, acc) when params == %{} do
    acc
  end

  defp to_schema_opt(params, "query", acc) do
    Map.put(acc, :query_schema, params)
  end

  defp to_schema_opt(params, "cookie", acc) do
    Map.put(acc, :cookie_schema, params)
  end

  defp to_schema_opt(params, "header", acc) do
    Map.put(acc, :header_schema, params)
  end

  defp to_schema_opt(params, "path", acc) do
    Map.put(acc, :path_schema, params)
  end

  defp step3_merge_others({acc, operation}, opts) do
    # Use the input `name_space` option from command line if existed
    name_space = opts[:name_space] || Map.get(operation, "x-oasis-name-space")

    acc
    |> Map.put(:operation_id, Map.get(operation, "operationId"))
    |> Map.put(:name_space, name_space)
  end

  defp build_files_to_generate(apps, router) do
    apps
    |> may_inject_request_validator(router)
    |> may_inject_plug_parsers()
    |> template_plugs_in_pair()
  end

  defp may_inject_plug_parsers(
         %__MODULE__{http_verb: http_verb, body_schema: %{"content" => content}} = router
       )
       when http_verb in ["post", "put", "patch", "delete"] do
    Map.put(router, :plug_parsers, inject_plug_parsers(content))
  end

  defp may_inject_plug_parsers(router), do: router

  defp inject_plug_parsers(content) do
    opts = [
      parsers: MapSet.new(),
      pass: ["*/*"],
      body_reader: {Oasis.CacheRawBodyReader, :read_body, []}
    ]

    opts =
      Enum.reduce(content, opts, fn {content_type, _}, opts ->
        map_plug_parsers(content_type, opts)
      end)

    parsers = MapSet.to_list(opts[:parsers])

    if parsers == [] do
      nil
    else
      opts = Keyword.put(opts, :parsers, parsers)
      ~s|plug(\nPlug.Parsers, #{inspect(opts)})|
    end
  end

  defp map_plug_parsers("application/x-www-form-urlencoded" <> _, acc) do
    parsers = MapSet.put(acc[:parsers], :urlencoded)
    Keyword.put(acc, :parsers, parsers)
  end

  defp map_plug_parsers("multipart/form-data" <> _, acc) do
    parsers = MapSet.put(acc[:parsers], :multipart)
    Keyword.put(acc, :parsers, parsers)
  end

  defp map_plug_parsers("multipart/mixed" <> _, acc) do
    parsers = MapSet.put(acc[:parsers], :multipart)
    Keyword.put(acc, :parsers, parsers)
  end

  defp map_plug_parsers("application/json" <> _, acc) do
    parsers = MapSet.put(acc[:parsers], :json)

    acc
    |> Keyword.put(:parsers, parsers)
    |> Keyword.put(:json_decoder, Jason)
  end

  defp map_plug_parsers(_, acc), do: acc

  defp may_inject_request_validator(apps, %{body_schema: body_schema} = router)
       when is_map(body_schema) do
    inject_request_validator(apps, router)
  end

  defp may_inject_request_validator(apps, %{query_schema: query_schema} = router)
       when is_map(query_schema) do
    inject_request_validator(apps, router)
  end

  defp may_inject_request_validator(apps, %{header_schema: header_schema} = router)
       when is_map(header_schema) do
    inject_request_validator(apps, router)
  end

  defp may_inject_request_validator(apps, %{cookie_schema: cookie_schema} = router)
       when is_map(cookie_schema) do
    inject_request_validator(apps, router)
  end

  defp may_inject_request_validator(_apps, router), do: router

  defp inject_request_validator(apps, router) do
    content =
      Mix.Oasis.eval_from(apps, "priv/templates/oas.gen.plug/request_validator.exs",
        router: router
      )

    Map.put(router, :request_validator, content)
  end

  defp template_plugs_in_pair(%__MODULE__{name_space: name_space} = router) do
    {name_space, dir} = Mix.Oasis.name_space(name_space)

    {module_name, plug_file_name} = Mix.Oasis.module_alias(router)
    {pre_plug_module_name, pre_plug_file_name} = Mix.Oasis.module_alias("Pre#{module_name}")

    pre_plug_module = Module.concat([name_space, pre_plug_module_name])
    plug_module = Module.concat([name_space, module_name])

    router =
      router
      |> Map.put(:plug_module, plug_module)
      |> Map.put(:pre_plug_module, pre_plug_module)

    {
      [
        {:eex, Path.join([dir, pre_plug_file_name]), "pre_plug.ex", pre_plug_module,
         router},
        {:new_eex, Path.join([dir, plug_file_name]), "plug.ex", plug_module, router}
      ],
      router
    }
  end
end
