defmodule Oasis.Spec.Parameter do
  @moduledoc false

  alias Oasis.InvalidSpecError

  @locations ["query", "head", "path", "cookie"]

  def build(path_expr, parameter) do
    parameter
    |> check_schema_or_content(parameter["schema"], parameter["content"])
    |> check_name(path_expr)
  end

  defp check_schema_or_content(parameter, nil, nil) do
    raise InvalidSpecError,
          "A parameter MUST contain either a schema property, or a content property, but not found any in #{
            inspect(parameter, pretty: true)
          }"
  end

  defp check_schema_or_content(parameter, schema, nil) when schema != nil do
    parameter
  end

  defp check_schema_or_content(parameter, nil, content) when content != nil do
    Enum.each(content, fn {content_type, media_type} ->
      if media_type["schema"] == nil do
        raise InvalidSpecError,
              "Not found required schema field in media type object #{inspect(content_type)}: #{
                inspect(media_type, pretty: true)
              } in parameter #{inspect(parameter, pretty: true)}"
      end
    end)

    parameter
  end

  defp check_schema_or_content(parameter, _schema, _content) do
    raise InvalidSpecError,
          "A parameter MUST contain either a schema property, or a content property, but found both in #{
            inspect(parameter, pretty: true)
          }"
  end

  defp check_name(%{"in" => "path", "name" => name, "required" => true} = parameter, path_expr)
       when is_bitstring(name) do
    if String.contains?(path_expr, name) do
      parameter
    else
      raise InvalidSpecError,
            "The name field: `#{name}` MUST correspond to a template expression occurring within the path: `#{
              path_expr
            }`"
    end
  end

  defp check_name(%{"in" => "path", "name" => name} = _parameter, path_expr)
       when is_bitstring(name) do
    raise InvalidSpecError,
          "The name field: `#{name}` MUST correspond to a template expression occurring within the path: `#{
            path_expr
          }`, and the property of required is REQUIRED and its value MUST be true, like: `required: true`"
  end

  defp check_name(%{"in" => "header", "name" => name} = parameter, _path_expr)
       when is_bitstring(name) do
    # If `in` is "header" and the name field is "Accept", "Content-Type" or "Authorization",
    # the parameter definition SHALL be ignored.
    lowercase = name |> String.trim() |> String.downcase()

    if lowercase in ["accept", "content-type", "authorization"] do
      nil
    else
      # Since `Plug` converts all names of header parameters in lowercase by default,
      # we need to do the same conversion as well when define schema of header parameter.
      Map.put(parameter, "name", lowercase)
    end
  end

  defp check_name(%{"in" => in_field} = _parameter, path_expr) when in_field not in @locations do
    raise InvalidSpecError,
          "The location of the parameter: `#{in_field}` is invalid in the path: `#{path_expr}`, expect to be one of #{
            inspect(@locations)
          }"
  end

  defp check_name(%{"name" => name} = parameter, path_expr) when is_bitstring(name) do
    if String.trim(name) == "" do
      raise InvalidSpecError, "The name of the parameter is missing in the path: `#{path_expr}`"
    end

    parameter
  end

  defp check_name(%{"name" => name} = _parameter, path_expr) do
    raise InvalidSpecError,
          "The name of the parameter expect to be a string, but got `#{inspect(name)}` in the path: `#{
            path_expr
          }`"
  end

  defp check_name(_parameter, path_expr) do
    raise InvalidSpecError, "The name of the parameter is missing in the path: `#{path_expr}`"
  end
end
