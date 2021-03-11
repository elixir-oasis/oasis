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

  defp build_json_schema({:error, %YamlElixir.FileNotFoundError{message: message}}) do
    {:error, %Oasis.FileNotFoundError{message: message}}
  end
  defp build_json_schema({:error, %YamlElixir.ParsingError{message: message}}) do
    {:error, %Oasis.InvalidSpecError{message: "Failed to parse yaml file: #{message}"}}
  end
  defp build_json_schema({:error, %Oasis.FileNotFoundError{} = error}) do
    {:error, error}
  end
  defp build_json_schema({:error, %Oasis.InvalidSpecError{} = error}) do
    {:error, error}
  end
  defp build_json_schema({:error, %Jason.DecodeError{data: data}}) do
    {:error, %Oasis.InvalidSpecError{message: "Failed to parse json file: `#{data}`"}}
  end

  defp extract_path_suffix(path) do
    suffix = path |> String.trim() |> String.slice(-4..-1) |> String.downcase()
    {suffix, path}
  end

  defp read_file({type, path}) when type == "yaml" or type == ".yml" do
    YamlElixir.read_from_file(path)
  end

  defp read_file({"json", path}) do
    case File.read(path) do
      {:ok, content} ->
        Jason.decode(content)
      {:error, posix} ->
        {:error, %Oasis.FileNotFoundError{message: "Failed to open file #{inspect(path)} with error #{posix}"}}
    end
  end

  defp read_file({invalid_type, _path}) do
    {:error, %Oasis.InvalidSpecError{message: "Expect a yml/yaml or json format file, but got: `#{invalid_type}`"}}
  end
end
