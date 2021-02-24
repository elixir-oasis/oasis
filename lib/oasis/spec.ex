defmodule Oasis.Spec do
  @moduledoc false

  require Logger

  alias __MODULE__

  def read(path) do
    path
    |> extract_path_suffix()
    |> read_file()
    |> build_json_schema()
  end

  defp build_json_schema({:ok, data}) do
    data
    |> ExJsonSchema.Schema.resolve()
    |> Spec.Utils.expand_ref()
    |> Spec.Path.build()
  end

  defp build_json_schema(error) do
    error
  end

  defp extract_path_suffix(path) do
    suffix = path |> String.trim() |> String.slice(-4..-1) |> String.downcase()
    {suffix, path}
  end

  defp read_file({type, path})
       when type == "yaml"
       when type == ".yml" do
    case YamlElixir.read_from_file(path) do
      {:ok, data} ->
        {:ok, data}

      {:error, error} ->
        Logger.error("Input invalid yaml content: #{inspect(error)}")
    end
  end

  defp read_file({"json", _path}) do
    :todo
  end

  defp read_file({invalid_type, path}) do
    Logger.error(
      "Input invalid file type: #{invalid_type} from path: #{inspect(path)}, please use a file in json or yaml format."
    )
  end
end
