defmodule Oasis.Spec.SpecTest do
  use ExUnit.Case

  @dir Path.expand("./file", __DIR__)

  test "parse basic info from yaml and json" do
    file_path = Path.join([@dir, "basic.yaml"])
    %ExJsonSchema.Schema.Root{schema: schema} = Oasis.Spec.read(file_path)

    assert schema["openapi"] == "3.1.0"

    info = schema["info"]

    assert info["title"] == "Test API" and info["version"] == "1.0.0"

    assert length(schema["servers"]) == 3

    file_path = Path.join([@dir, "basic.json"])
    %ExJsonSchema.Schema.Root{schema: schema_from_json} = Oasis.Spec.read(file_path)

    assert schema_from_json == schema
  end

  test "input invalid path" do
    {:error, %Oasis.FileNotFoundError{message: message}} = Oasis.Spec.read("unknown.yaml")
    assert message =~ ~s/Failed to open file "unknown.yaml"/

    {:error, %Oasis.FileNotFoundError{message: message}} = Oasis.Spec.read("unknown.json")
    assert message =~ ~s/Failed to open file "unknown.json" with error enoent/
  end

  test "invalid yaml file content" do
    file_path = Path.join([@dir, "malformed.yml"])
    {:error, %Oasis.InvalidSpecError{message: message}} = Oasis.Spec.read(file_path)
    assert message =~ ~s/Failed to parse yaml file: malformed yaml/

    file_path = Path.join([@dir, "invalid.yml"])
    {:error, %Oasis.InvalidSpecError{message: message}} = Oasis.Spec.read(file_path)
    assert message =~ ~s/Failed to parse yaml file: No anchor corresponds to alias "invalid"/

    file_path = Path.join([@dir, "invalid.json"])
    {:error, %Oasis.InvalidSpecError{message: message}} = Oasis.Spec.read(file_path)
    assert message =~ ~s/Failed to parse json file: `invalid\n`/
  end

  test "invalid format file type" do
    {:error, %Oasis.InvalidSpecError{message: message}} = Oasis.Spec.read("hello.txt")
    assert message =~ ~s(Expect a yml/yaml or json format file, but got: `.txt`)
  end

  test "parse post requestBodies" do
    file_path = Path.join([@dir, "basic.yaml"])
    %ExJsonSchema.Schema.Root{schema: schema} = Oasis.Spec.read(file_path)

    request_body_of_refresh_token = schema["paths"]["/refresh_token"]["post"]["requestBody"]
    assert request_body_of_refresh_token["required"] == true

    schema = request_body_of_refresh_token["content"]["application/json"]["schema"]
    schema = ExJsonSchema.Schema.resolve(schema)

    assert ExJsonSchema.Validator.validate(schema, %{"refresh_token" => "123"}) == :ok

    assert {:error, _} = ExJsonSchema.Validator.validate(schema, %{})
  end
end
