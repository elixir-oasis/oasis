defmodule Oasis.Spec.Path do
  @moduledoc false

  @regex_url ~r/{.*?}/

  @supported_http_verbs [
    "delete",
    "get",
    "head",
    "options",
    "patch",
    "post",
    "put"
  ]

  require Logger

  @doc """
  Format Path object's URI template into `Plug.Router` definition.

  For example:

    format /users/{id} to /users/:id
    format /users/{id*} to /users/:id
    format /users/{.id} to /users/:id
    format /users/{.id*} to /users/:id
    format /users/{;id} to /users/:id
    format /users/{;id*} to /users/:id
  """
  def format_url(url) do
    Regex.replace(@regex_url, url, fn matched, _ ->
      ":#{String.replace(matched, ["{", "}", ".", ";", "*"], "")}"
    end)
  end

  def supported_http_verbs(), do: @supported_http_verbs

  def build(%{schema: schema} = root) do
    paths = schema["paths"] || %{}

    paths =
      Enum.reduce(paths, %{}, fn
        {"/" <> _ = path_expr, _info} = path, acc ->
          Map.put(acc, format_url(path_expr), map_path(path))

        {field, value}, acc ->
          Map.put(acc, field, value)
      end)
    schema = Map.put(schema, "paths", paths)

    %{root | schema: schema}
  end

  defp map_path({path_expr, info}) do
    {global_params, rest} = Map.pop(info, "parameters", [])

    Enum.reduce(rest, %{}, fn {field, value}, acc ->
      value =
        map_path_item_object(
          field,
          path_expr,
          value,
          global_params
        )

      Map.put(acc, field, value)
    end)
  end

  defp map_path_item_object(http_verb, path_expr, operation, global_params)
       when http_verb in @supported_http_verbs do
    Oasis.Spec.Operation.build(path_expr, operation, global_params)
  end

  defp map_path_item_object("trace", path_expr, _operation, _global_params) do
    raise Oasis.InvalidSpecError, "Not Support `trace` http method from `#{path_expr}` path"
  end

  defp map_path_item_object(_other_field, _, value, _global_params) do
    value
  end
end
