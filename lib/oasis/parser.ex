defmodule Oasis.Parser do
  @moduledoc false

  def parse(type, value) when is_bitstring(value) do
    do_parse(type, value)
  end

  def parse(%{"type" => "null"}, nil), do: nil

  def parse(%{"type" => "array"} = type, value) when is_list(value) do
    do_parse_array(type, value)
  end

  def parse(%{"type" => "object"} = type, value) when is_map(value) do
    do_parse_object(type, value)
  end

  def parse(_type, value), do: value

  defp do_parse(%{"type" => type}, value)
       when is_bitstring(value) and type in ["array", "object"] do
    case Jason.decode(value) do
      {:ok, value} ->
        value

      {:error, _error} ->
        raise_argument_error()
    end
  end

  defp do_parse(%{"type" => "boolean"}, "true"), do: true
  defp do_parse(%{"type" => "boolean"}, "false"), do: false
  defp do_parse(%{"type" => "boolean"}, value), do: value

  defp do_parse(%{"type" => "number"}, value) do
    case Float.parse(value) do
      {value, ""} ->
        value

      _ ->
        raise_argument_error()
    end
  end

  defp do_parse(%{"type" => "integer"}, value) do
    String.to_integer(value)
  end

  defp do_parse(%{"type" => "string"}, value) do
    value
  end

  defp do_parse(_type, value) do
    value
  end

  defp do_parse_array(%{"items" => %{"type" => _type} = schema}, list) do
    Enum.map(list, fn value ->
      parse(schema, value)
    end)
  end

  defp do_parse_array(%{"items" => items}, list)
       when is_list(items) and length(items) == length(list) do
    items
    |> Enum.zip(list)
    |> Enum.map(fn {type, value} ->
      parse(type, value)
    end)
  end

  defp do_parse_array(%{"items" => items}, list)
       when is_list(items) and length(items) != length(list) do
    raise_argument_error()
  end

  defp do_parse_array(_, list), do: list

  defp do_parse_object(
         %{"properties" => properties, "additionalProperties" => additional_properties} = type,
         map
       )
       when is_map(properties) and is_map(additional_properties) do
    properties_of_dependencies = properties_from_schema_dependencies(type)

    properties = Map.merge(properties, properties_of_dependencies)

    pattern_properties = pattern_properties(type)

    Enum.reduce(map, map, fn {name, value}, acc ->
      type = type_to_parse_property(name, properties, pattern_properties, additional_properties)
      Map.put(acc, name, parse(type, value))
    end)
  end

  defp do_parse_object(%{"properties" => properties} = type, map) when is_map(properties) do
    properties_of_dependencies = properties_from_schema_dependencies(type)

    properties = Map.merge(properties, properties_of_dependencies)

    pattern_properties = pattern_properties(type)

    Enum.reduce(map, map, fn {name, value}, acc ->
      type = type_to_parse_property(name, properties, pattern_properties)

      if type == nil do
        acc
      else
        Map.put(acc, name, parse(type, value))
      end
    end)
  end

  defp do_parse_object(_, map), do: map

  defp properties_from_schema_dependencies(type) do
    type
    |> Map.get("dependencies", %{})
    |> Enum.reduce(%{}, fn
      {_name, definition}, acc when is_map(definition) ->
        # schema dependencies
        properties = Map.get(definition, "properties", %{})
        Map.merge(acc, properties)

      _, acc ->
        acc
    end)
  end

  defp pattern_properties(type) do
    type
    |> Map.get("patternProperties", %{})
    |> Enum.reduce([], fn {pattern, definition}, acc ->
      regex = Regex.compile!(pattern)
      [{regex, definition} | acc]
    end)
  end

  defp type_to_parse_property(name, properties, pattern_properties, additional_properties \\ nil) do
    type = Map.get(properties, name)

    if type == nil do
      # may find a matched property from "patternProperties" by name
      pattern = type_from_pattern_properties(name, pattern_properties)

      if pattern == nil do
        # `additional_properties` may be as nil or a schema (with only a type for any additional properties)
        additional_properties
      else
        {_, type} = pattern
        type
      end
    else
      type
    end
  end

  defp type_from_pattern_properties(_name, []), do: nil

  defp type_from_pattern_properties(name, pattern_properties) do
    Enum.find(pattern_properties, fn {regex, _definition} ->
      Regex.match?(regex, name)
    end)
  end

  defp raise_argument_error() do
    raise ArgumentError, "argument error"
  end
end
