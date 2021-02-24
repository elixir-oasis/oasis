defmodule Oasis.Test.Support.Spec do
  def yaml_to_json_schema(yaml_str) do
    {:ok, data} = YamlElixir.read_from_string(yaml_str)
    ExJsonSchema.Schema.resolve(data)
  end
end
