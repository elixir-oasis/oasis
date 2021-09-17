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
    :plug_parsers,
    :security
  ]

  @check_parameter_fields [
    "query",
    "cookie",
    "header",
    "path"
  ]

  @spec_ext_name_space "x-oasis-name-space"
  @spec_ext_router "x-oasis-router"
  @spec_ext_key_to_assigns "x-oasis-key-to-assigns"
  @spec_ext_signed_headers "x-oasis-signed-headers"

  def generate_files_by_paths_spec(apps, %{"paths" => paths_spec} = spec, opts)
    when is_map(paths_spec) do

    opts = put_opts(spec, opts)

    {name_space_from_paths, paths_spec} = Map.pop(paths_spec, @spec_ext_name_space)

    {plug_files, routers} = generate_plug_files(apps, paths_spec, name_space_from_paths, opts)

    router_file = generate_router_file(routers, name_space_from_paths, opts)

    [router_file | plug_files]
  end

  defp put_opts(%{"paths" => paths_spec} = spec, opts) do
    # Set the :router use the input option from command line if exists,
    # or use the Paths Object's extension "x-oasis-router" field if exists.
    router = opts[:router] || Map.get(paths_spec, @spec_ext_router)

    opts
    |> Keyword.put(:router, router)
    |> Keyword.put(:global_security, global_security(spec))
  end

  defp generate_plug_files(apps, paths_spec, name_space_from_paths, opts) do
    paths_spec
    |> Map.keys()
    |> Enum.reduce({[], []}, fn url, acc ->
      iterate_paths_spec_by_url(apps, paths_spec, url, acc, name_space_from_paths, opts)
    end)
  end

  defp iterate_paths_spec_by_url(
         apps,
         paths_spec,
         "/" <> _ = url,
         {plug_files_acc, routers_acc},
         name_space,
         opts
       ) do
    # `paths_spec` may contain extended object starts with `x-oasis-`,
    # assume a value starts with "/" is a proper url expression.
    {plug_files, routers} =
      paths_spec
      |> Map.get(url, %{})
      |> Map.take(Oasis.Spec.Path.supported_http_verbs())
      |> Enum.reduce({[], []}, fn {http_verb, operation}, {plug_files_to_url, routers_to_url} ->

        operation = Map.put_new(operation, @spec_ext_name_space, name_space)

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

  defp iterate_paths_spec_by_url(_apps, _paths_spec, _url, acc, _name_space, _opts), do: acc

  defp generate_router_file(routers, name_space, opts) do
    name_space = opts[:name_space] || name_space
    {name_space, dir} = Mix.Oasis.name_space(name_space)

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

    build_files_to_generate(apps, router, opts)
  end

  defp build_operation(operation, opts) do
    operation
    |> merge_parameters_to_operation()
    |> merge_request_body_to_operation()
    |> merge_security_to_operation(opts)
    |> merge_others_to_operation(opts)
  end

  defp merge_parameters_to_operation(%{"parameters" => parameters} = operation) do
    router =
      @check_parameter_fields
      |> Enum.reduce(%{}, fn location, acc ->
        parameters_to_location = Map.get(parameters, location)

        params_to_schema = group_schemas_by_location(location, parameters_to_location)

        to_schema_opt(params_to_schema, location, acc)
      end)

    {router, operation}
  end

  defp merge_parameters_to_operation(operation), do: {%{}, operation}

  defp merge_request_body_to_operation(
         {acc, %{"requestBody" => %{"content" => content} = request_body} = operation}
       )
       when is_map(content) do
    content =
      Enum.reduce(content, %{}, fn {content_type, media}, acc ->
        schema = Map.get(media, "schema")

        if schema != nil do
          media = Map.put(media, "schema", %ExJsonSchema.Schema.Root{schema: schema})
          Map.put(acc, content_type, media)
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

  defp merge_request_body_to_operation({acc, operation}), do: {acc, operation}

  defp put_required_if_exists(%{"required" => required}, map)
       when is_boolean(required) and is_map(map) do
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
    parameter =
      put_required_if_exists(parameter, %{"schema" => %ExJsonSchema.Schema.Root{schema: schema}})

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

  defp merge_security_to_operation({acc, operation}, opts) do
    security =
      case opts[:global_security] do
        {nil, security_schemes} ->
          Oasis.Spec.Security.build(operation, security_schemes)
        {global_security, _} ->
          global_security
      end

    {
      Map.put(acc, :security, security),
      operation
    }
  end

  defp merge_others_to_operation({acc, operation}, opts) do
    # Use the input `name_space` option from command line if existed
    name_space_from_spec = Map.get(operation, @spec_ext_name_space)
    name_space = opts[:name_space] || name_space_from_spec

    acc
    |> Map.put(:operation_id, Map.get(operation, "operationId"))
    |> Map.put(:name_space, name_space)
  end

  defp build_files_to_generate(apps, router, opts) do
    {files, router} =
      apps
      |> may_inject_request_validator(router)
      |> may_inject_plug_parsers()
      |> template_plugs_in_pair()

    {security_files, router} = may_inject_plug_security(apps, router, opts)

    files =
      files
      |> Kernel.++(security_files)
      |> Enum.map(fn(file) ->
        Tuple.append(file, router)
      end)

    {
      files,
      router
    }
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
      Mix.Oasis.eval_from(apps, "priv/templates/oas.gen.plug/plug/request_validator.exs",
        router: router
      )

    Map.put(router, :request_validator, content)
  end

  defp may_inject_plug_security(_apps, %{security: nil} = router, _opts) do
    {[], router}
  end
  defp may_inject_plug_security(apps, %{security: security} = router, opts) when is_list(security) do
    {security, files} =
      Enum.reduce(security, [], fn {security_name, security_scheme}, acc ->
        security_scheme = map_security_scheme(apps, security_name, security_scheme, router, opts)
        acc ++ [security_scheme]
      end)
      |> Enum.unzip()

    router = Map.put(router, :security, security)

    {files, router}
  end

  defp map_security_scheme(apps, security_name, %{"scheme" => "bearer"} = security_scheme, %{name_space: name_space}, opts) do
    # priority use `x-oasis-name-space` field in security scheme object compare to operation's level
    # but still use the input argument option from the `oas.gen.plug` command line in the highest priority if possible.
    name_space_from_spec = Map.get(security_scheme, @spec_ext_name_space, name_space)
    name_space = opts[:name_space] || name_space_from_spec

    {name_space, dir} = Mix.Oasis.name_space(name_space)

    {module_name, file_name} = Mix.Oasis.module_alias(security_name)
    security_module = Module.concat([name_space, module_name])

    key_to_assigns = Map.get(security_scheme, @spec_ext_key_to_assigns)

    content =
      Mix.Oasis.eval_from(apps, "priv/templates/oas.gen.plug/plug/bearer_auth.exs",
        security: security_module,
        key_to_assigns: key_to_assigns
      )

    {
      content,
      {:new_eex, Path.join(dir, file_name), "bearer_token.ex", security_module}
    }
  end

  defp map_security_scheme(apps, security_name, %{"scheme" => "hmac-" <> _} = security_scheme, %{name_space: name_space}, opts) do
    # priority use `x-oasis-name-space` field in security scheme object compare to operation's level
    # but still use the input argument option from the `oas.gen.plug` command line in the highest priority if possible.
    scheme = security_scheme["scheme"]
    name_space_from_spec = Map.get(security_scheme, @spec_ext_name_space, name_space)
    name_space = opts[:name_space] || name_space_from_spec

    {name_space, dir} = Mix.Oasis.name_space(name_space)

    {module_name, file_name} = Mix.Oasis.module_alias(security_name)
    security_module = Module.concat([name_space, module_name])

    signed_headers = Map.get(security_scheme, @spec_ext_signed_headers)

    content =
      Mix.Oasis.eval_from(apps, "priv/templates/oas.gen.plug/plug/hmac_auth.exs",
        scheme: scheme,
        security: security_module,
        signed_headers: signed_headers
      )

    {
      content,
      {:new_eex, Path.join(dir, file_name), "hmac_token.ex", security_module}
    }
  end

  defp template_plugs_in_pair(%{name_space: name_space} = router) do
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
        {:eex, Path.join([dir, pre_plug_file_name]), "pre_plug.ex", pre_plug_module},
        {:new_eex, Path.join([dir, plug_file_name]), "plug.ex", plug_module}
      ],
      router
    }
  end

  defp global_security(spec) do
    security_schemes = Oasis.Spec.Security.security_schemes(spec)

    {
      Oasis.Spec.Security.build(spec, security_schemes),
      security_schemes
    }
  end

end
