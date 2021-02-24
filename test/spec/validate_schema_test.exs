defmodule Oasis.Spec.ValidateSchemaTest do
  use ExUnit.Case

  import Oasis.Test.Support.Spec

  test "path object build parameters" do
    yaml_str = """
      components:
        schemas:
          Content:
            type: object
            required:
              - name
              - tag
            properties:
              name:
                type: string
              tag:
                type: integer

      paths:
        /page:
          parameters:
            - name: lang
              in: query
              required: true
              schema: 
                type: integer
            - name: content
              in: query
              required: false
              style: simple
              schema:
                type: string
          get:
            operationId: fetch_page
            parameters:
              - name: content
                in: query
                required: false
                content:
                  application/json:
                    schema:
                      $ref: '#/components/schemas/Content'
    """

    root =
      yaml_str
      |> yaml_to_json_schema()
      |> Oasis.Spec.Utils.expand_ref()
      |> Oasis.Spec.Path.build()

    # the returned parameters by `name` property in asc order
    schema = root.schema

    operation = schema["paths"]["/page"]["get"]

    assert operation["operationId"] == "fetch_page"

    query_parameters = operation["parameters"]["query"]

    assert length(query_parameters) == 2

    [p1, p2] = query_parameters
    assert p1["name"] == "content" and p2["name"] == "lang"

    assert p1["required"] == false
    param_content_schema = p1["content"]["application/json"]["schema"]

    assert param_content_schema["type"] == "object"

    properties = param_content_schema["properties"]
    assert properties["name"] == %{"type" => "string"}
    assert properties["tag"] == %{"type" => "integer"}
  end

  test "parameter object with content and schema property" do
    yaml_str = """
      paths:
        /content:
          parameters:
            - name: lang
              in: query
              schema:
                type: string
              content:
                application/json:
                  schema:
                    properties:
                      name:
                        description: test desc
                        type: string
                    required:
                      - name
          get:
            operationId: content
            parameters:
              - name: tag
                in: query
                schema:
                  type: string
    """

    root = yaml_to_json_schema(yaml_str)

    assert_raise Oasis.InvalidSpecError, ~r/found both/, fn ->
      Oasis.Spec.Path.build(root)
    end
  end

  test "parameter object without content and schema property" do
    yaml_str = """
      paths:
        /content:
          get:
            operationId: content
            parameters:
              - name: tag
                in: query
    """

    root = yaml_to_json_schema(yaml_str)

    assert_raise Oasis.InvalidSpecError,
                 ~r/A parameter MUST contain either a schema property, or a content property, but not found any/,
                 fn ->
                   Oasis.Spec.Path.build(root)
                 end

    yaml_str = """
      paths:
        /content:
          get:
            operationId: content
            parameters:
              - name: tag
                in: query
                required: true
                content:
                  application/json:
                    example: test
    """

    root = yaml_to_json_schema(yaml_str)

    assert_raise Oasis.InvalidSpecError,
                 ~r(Not found required schema field in media type object "application/json"),
                 fn ->
                   Oasis.Spec.Path.build(root)
                 end
  end

  test "location of parameter object" do
    yaml_str = """
      paths:
        /content:
          get:
            operationId: content
            parameters:
              - name: tag
                in: invalid_location
                schema:
                  type: string
    """

    root = yaml_to_json_schema(yaml_str)

    assert_raise Oasis.InvalidSpecError, ~r(is invalid in the path: `/content`), fn ->
      Oasis.Spec.Path.build(root)
    end

    yaml_str = """
      paths:
        /content:
          get:
            operationId: content
            parameters:
              - name: accept
                in: header
                schema:
                  type: string
              - name: Authorization
                in: header
                schema:
                  type: string
              - name: accept
                in: query
                schema:
                  type: integer
    """

    root =
      yaml_str
      |> yaml_to_json_schema()
      |> Oasis.Spec.Path.build()

    parameters = root.schema["paths"]["/content"]["get"]["parameters"]

    header = parameters["header"]
    assert header == []

    query = parameters["query"]
    query_param = Enum.at(query, 0)
    assert query_param["name"] == "accept" and query_param["schema"]["type"] == "integer"
  end

  test "name of parameter object" do
    yaml_str = """
      paths:
        /content/{id}:
          get:
            operationId: content
            parameters:
              - name: tag
                in: query
                schema:
                  type: string
    """

    root =
      yaml_str
      |> yaml_to_json_schema()
      |> Oasis.Spec.Path.build()

    query = root.schema["paths"]["/content/{id}"]["get"]["parameters"]["query"]

    assert length(query) == 1
    assert Enum.at(query, 0)["name"] == "tag"

    yaml_str = """
      paths:
        /content/{id}:
          get:
            operationId: content
            parameters:
              - name: tag
                in: query
                schema:
                  type: string
              - name: typo_id
                in: path
                schema:
                  type: integer
    """

    root = yaml_to_json_schema(yaml_str)

    assert_raise Oasis.InvalidSpecError,
                 ~r(MUST correspond to a template expression occurring within the path: `/content/{id}`),
                 fn ->
                   Oasis.Spec.Path.build(root)
                 end
  end
end
