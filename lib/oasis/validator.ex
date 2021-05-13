defmodule Oasis.Validator do
  @moduledoc false

  alias Oasis.BadRequestError

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

  defp check_required!(%{"required" => true}, use_in, param_name, nil) do
    raise BadRequestError,
      error: %BadRequestError.Required{},
      use_in: use_in,
      param_name: param_name,
      message: "Missing a required parameter"
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

  defp do_parse_and_validate!(%{schema: schema} = json_schema_root, use_in, param_name, value) do
    try do
      Oasis.Parser.parse(schema, value)
    rescue
      ArgumentError ->
        raise BadRequestError,
          error: %BadRequestError.Invalid{value: value},
          use_in: use_in,
          param_name: param_name,
          message: "Failed to convert parameter"

    else
      parsed ->

        result =
          json_schema_root
          |> json_schema_validate(parsed)
          |> recheck_after_validate()

        case result do
          {:ok, ^parsed} ->
            parsed
          {:error, %ExJsonSchema.Validator.Error{error: error, path: path}} ->
            raise BadRequestError,
              error: %BadRequestError.JsonSchemaValidationFailed{error: error, path: path},
              use_in: use_in,
              param_name: param_name,
              message: "Failed to validate JSON schema with an error: #{to_string(error)}"
        end
    end
  end


  defp json_schema_validate(json_schema_root, parsed) do
    {
      ExJsonSchema.Validator.validate(json_schema_root, parsed, error_formatter: false),
      parsed
    }
  end

  defp recheck_after_validate({:ok, parsed}), do: {:ok, parsed}
  defp recheck_after_validate({{:error, errors}, parsed}) do
    errors = Enum.filter(errors, fn %{error: error, path: path} ->
      error_to_attention?(error, path, parsed)
    end)

    case errors do
      [] ->
        {:ok, parsed}
      [error | _] ->
        {:error, error}
    end
  end

  defp error_to_attention?(%ExJsonSchema.Validator.Error.Type{actual: "object", expected: ["string"]}, path, parsed) do
    case value_in_path(path, parsed) do
      %Plug.Upload{} ->
        # ignore `Plug.Upload` failed in json schema validation
        false
      _ ->
        true
    end
  end
  defp error_to_attention?(_error, _path, _parsed), do: true

  defp value_in_path("#/" <> path, parsed) when is_map(parsed) do
    get_in(parsed, String.split(path, "/"))
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

end
