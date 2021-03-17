defmodule Oasis.Router do
  @moduledoc ~S"""
  Base on `Plug.Router` to add a pre-parser to convert and validate the path param(s) in the
  final generated HTTP verb match functions.

  The generated router module uses `Oasis.Router` to instead of `Plug.Router`, in fact, they don't make a
  huge difference, except that specify parameters which will then be available and types coverted
  in the function body:

      get("/hello/:id",
        private: %{
          path_schema: %{
            "id" => %{
              "schema" => %ExJsonSchema.Schema.Root{
                schema: %{"type" => "integer"}
              }
            }
          }
        }) do
        # Notice that the `:id` variable is an integer
        send_resp(conn, 200, "hello #{id}")
      end

  The `:id` parameter will also be available and coverted as an integer in the function body as
  `conn.params["id"]` and `conn.path_params["id"]`.
  """

  @doc false
  defmacro __using__(_opts) do
    quote location: :keep do
      use Plug.Router

      import Plug.Router,
        except: [
          delete: 3,
          delete: 2,
          get: 3,
          get: 2,
          head: 3,
          head: 2,
          options: 3,
          options: 2,
          patch: 3,
          patch: 2,
          post: 3,
          post: 2,
          put: 3,
          put: 2
        ]

      import Oasis.Router

      @before_compile Oasis.Router

      Module.register_attribute(__MODULE__, :oas_path_schemas, accumulate: true)

      def match(conn, _opts) do
        parse_and_then_do_match(conn, conn.method, Plug.Router.Utils.decode_path_info!(conn))
      end
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    compile_match(env)
  end

  defp compile_match(env) do
    oas_path_schemas = Module.get_attribute(env.module, :oas_path_schemas, [])

    default_ast =
      quote location: :keep do
        defp parse_and_then_do_match(conn, _method, match) do
          do_match(conn, conn.method, match, conn.host)
        end
      end

    Enum.reduce(oas_path_schemas, [{:__block__, [], [default_ast]}], fn path_schema, acc ->
      [compile_match_by_path_schema(path_schema) | acc]
    end)
  end

  defp compile_match_by_path_schema({method, path, type, options}) do
    {_vars, match} = Plug.Router.Utils.build_path_match(path)

    schemas = map_path_schemas(match, type)

    plug_to = options[:to]

    quote location: :keep,
          bind_quoted: [
            method: method,
            plug_to: plug_to,
            match: Macro.escape(match, unquote: true),
            schemas: Macro.escape(schemas, unquote: true)
          ] do
      defp parse_and_then_do_match(conn, unquote(method), unquote(match)) do
        match =
          unquote(match)
          |> Enum.zip(unquote(schemas))
          |> Enum.map(fn
            {value, nil} ->
              value

            {value, {key, definition}} ->
              try do
                Oasis.Validator.parse_and_validate!(definition, "path", key, value)
              rescue
                reason in Plug.BadRequestError ->
                  plug_to = unquote(plug_to)
                  module = if plug_to == nil, do: __MODULE__, else: plug_to

                  Plug.ErrorHandler.__catch__(
                    conn,
                    :error,
                    reason,
                    reason,
                    __STACKTRACE__,
                    &module.handle_errors/2
                  )
              end
          end)

        do_match(conn, conn.method, match, conn.host)
      end
    end
  end

  defp map_path_schemas(match, type) do
    Enum.map(match, fn
      {param_name, _, _} ->
        param_name = Atom.to_string(param_name)
        {param_name, Macro.escape(Map.get(type, param_name))}

      _ ->
        nil
    end)
  end

  @doc false
  defmacro put_attribute_oas_path_schemas(_method, _path, nil, _options), do: nil

  defmacro put_attribute_oas_path_schemas(method, path, path_schema, options) do
    quote location: :keep do
      Module.put_attribute(
        __MODULE__,
        :oas_path_schemas,
        {
          Plug.Router.Utils.normalize_method(unquote(method)),
          unquote(path),
          unquote(path_schema),
          unquote(options)
        }
      )
    end
  end

  @doc false
  defmacro delete(path, options, contents \\ []) do
    expand_route_match(__ENV__, path, options, contents)
  end

  @doc false
  defmacro get(path, options, contents \\ []) do
    expand_route_match(__ENV__, path, options, contents)
  end

  @doc false
  defmacro head(path, options, contents \\ []) do
    expand_route_match(__ENV__, path, options, contents)
  end

  @doc false
  defmacro options(path, options, contents \\ []) do
    expand_route_match(__ENV__, path, options, contents)
  end

  @doc false
  defmacro patch(path, options, contents \\ []) do
    expand_route_match(__ENV__, path, options, contents)
  end

  @doc false
  defmacro post(path, options, contents \\ []) do
    expand_route_match(__ENV__, path, options, contents)
  end

  @doc false
  defmacro put(path, options, contents \\ []) do
    expand_route_match(__ENV__, path, options, contents)
  end

  defp expand_route_match(%Macro.Env{function: {http_verb, _}}, path, options, contents) do
    path_schema = extrace_path_schema_from_options(options)

    quote location: :keep do
      put_attribute_oas_path_schemas(unquote_splicing([http_verb, path, path_schema, options]))

      Plug.Router.unquote(http_verb)(unquote_splicing([path, options, contents]))
    end
  end

  defp extrace_path_schema_from_options(options) when is_list(options) do
    extrace_path_schema(options[:private])
  end

  defp extrace_path_schema_from_options(_options), do: nil

  defp extrace_path_schema({_, _, opts}), do: Keyword.get(opts, :path_schema)
  defp extrace_path_schema(_), do: nil
end
