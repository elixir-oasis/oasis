defmodule Oasis.Spec.ParseYarmlTest do
  use ExUnit.Case

  @yaml_dir Path.expand("./yaml", __DIR__)

  test "parse info and server object" do
    file_path = Path.join([@yaml_dir, "basic.yaml"])
    %ExJsonSchema.Schema.Root{schema: schema} = Oasis.Spec.read(file_path)

    assert schema["openapi"] == "3.1.0"

    info = schema["info"]

    assert info["title"] == "Test API" and info["version"] == "1.0.0"

    assert length(schema["servers"]) == 3
  end
end
