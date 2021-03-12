defmodule Oasis.Validator do
  @moduledoc false

  @spec parse_and_validate!(
          param :: map() | nil,
          use_in :: String.t(),
          name :: String.t(),
          value :: term()
        ) :: term()
  def parse_and_validate!(%{"schema" => _schema} = definition, use_in, name, value) do
    definition
    |> prepare()
    |> check_required!(use_in, name, value)
    |> process()
  end

  def parse_and_validate!(%{"content" => _content} = definition, use_in, name, value) do
    definition
    |> prepare()
    |> check_required!(use_in, name, value)
    |> process()
  end

  def parse_and_validate!(_, _, _, value) do
    value
  end

  defp prepare(definition) when is_map(definition) do
    required = if definition["required"] == true, do: true, else: false

    Map.put(definition, "required", required)
  end

  defp check_required!(%{"required" => true}, use_in, name, nil) do
    raise Plug.BadRequestError,
      message: "Required the #{use_in} parameter #{inspect(name)} is missing"
  end

  defp check_required!(definition, use_in, name, value) do
    {definition, use_in, name, value}
  end

  defp process({_, _use_in, _name, nil}) do
    nil
  end

  defp process({%{"schema" => json_schema_root}, use_in, name, value}) do
    do_parse_and_validate!(json_schema_root, use_in, name, value)
  end

  defp process({%{"content" => content}, use_in, name, value}) do
    [{content_type, media_type} | _] = Map.to_list(content)

    content_type
    |> String.downcase()
    |> process_media_type(media_type, use_in, name, value)
  end

  defp do_parse_and_validate!(%{schema: schema} = json_schema_root, use_in, name, value) do
    try do
      Oasis.Parser.parse(schema, value)
    rescue
      ArgumentError ->
        raise_fail_to_parse(use_in, name, value, schema)
    else
      value ->
        case ExJsonSchema.Validator.validate(json_schema_root, value) do
          :ok ->
            value

          {:error, [{message, path} | _]} ->
            raise_fail_to_schema_validate(use_in, name, value, message, path)
        end
    end
  end

  defp process_media_type("text/plain", %{"schema" => json_schema_root}, use_in, name, value) do
    do_parse_and_validate!(json_schema_root, use_in, name, value)
  end

  defp process_media_type(
         "text/plain" <> _charset,
         %{"schema" => json_schema_root},
         use_in,
         name,
         value
       ) do
    do_parse_and_validate!(json_schema_root, use_in, name, value)
  end

  defp process_media_type(
         content_type,
         %{"schema" => json_schema_root},
         use_in,
         name,
         value
       )
       when content_type == "application/json"
       when content_type == "application/x-www-form-urlencoded" do
    do_parse_and_validate!(json_schema_root, use_in, name, value)
  end

  defp process_media_type(
         "multipart/form-data" <> _boundary,
         %{"schema" => json_schema_root},
         use_in,
         name,
         value
       ) do
    do_parse_and_validate!(json_schema_root, use_in, name, value)
  end

  defp process_media_type(
         "multipart/mixed" <> _boundary,
         %{"schema" => json_schema_root},
         use_in,
         name,
         value
       ) do
    do_parse_and_validate!(json_schema_root, use_in, name, value)
  end

  defp process_media_type(
         "application/" <> subtype,
         %{"schema" => json_schema_root},
         use_in,
         name,
         value
       ) do
    if String.ends_with?(subtype, "+json") do
      do_parse_and_validate!(json_schema_root, use_in, name, value)
    else
      value
    end
  end

  defp process_media_type(_content_type, _schema, _use_in, _name, value) do
    value
  end

  defp raise_fail_to_parse("body", _, value, schema) do
    raise Plug.BadRequestError,
      message:
        "Failed to transfer the value #{inspect(value)} of the body request by schema: #{
          inspect(schema)
        }"
  end

  defp raise_fail_to_parse(use_in, name, value, schema) do
    raise Plug.BadRequestError,
      message:
        "Failed to transfer the value #{inspect(value)} of the #{use_in} parameter #{inspect(name)} by schema: #{
          inspect(schema)
        }"
  end

  defp raise_fail_to_schema_validate("body", _, value, message, "#") do
    raise Plug.BadRequestError,
      message: "#{message} for the body request, but got #{inspect(value)}"
  end

  defp raise_fail_to_schema_validate(use_in, name, value, message, "#") do
    raise Plug.BadRequestError,
      message:
        "#{message} for the #{use_in} parameter #{inspect(name)}, but got #{inspect(value)}"
  end

  defp raise_fail_to_schema_validate("body", _, value, message, path) do
    raise Plug.BadRequestError,
      message: "#{message} for the body request in #{inspect(path)}, but got #{inspect(value)}"
  end

  defp raise_fail_to_schema_validate(use_in, name, value, message, path) do
    raise Plug.BadRequestError,
      message:
        "#{message} for the #{use_in} parameter #{inspect(name)} in #{inspect(path)}, but got #{
          inspect(value)
        }"
  end
end
