defmodule Oasis.Test.Spec.UtilsTest do
  use ExUnit.Case

  test "expand $ref" do
    yaml_str = """
      components:
        schemas:
          Content:
            type: object
            required:
              - name
              - tags
            properties:
              name:
                type: string
              tags:
                type: array
                items:
                  $ref: "#/components/schemas/Tag"
          Contents:
            type: array
            items:
              $ref: "#/components/schemas/Content"
          Tag:
            type: string
        pathItems:
          CommonContent:
            get:
              parameters:
                - name: content
                  in: query
                  schema:
                    $ref: "#/components/schemas/Contents"
      paths:
        /page:
          $ref: "#/components/pathItems/CommonContent"
        /contents:
          post:
            requestBody:
              description: Callback payload
              content:
                'application/json':
                  schema:
                    $ref: '#/components/schemas/Contents'
            responses:
              '200':
                description: callback successfully processed
          $ref: "#/components/pathItems/CommonContent"
    """

    {:ok, data} = YamlElixir.read_from_string(yaml_str)

    root = ExJsonSchema.Schema.resolve(data)

    root = Oasis.Spec.Utils.expand_ref(root)
    assert is_struct(root, ExJsonSchema.Schema.Root)

    schema = root.schema

    comp_schemas = get_in(schema, ["components", "schemas"])

    ref_tag = get_in(comp_schemas, ["Content", "properties", "tags", "items"])

    assert ref_tag == %{"type" => "string"}

    ref_contents = get_in(comp_schemas, ["Contents", "items"])

    content = %{
      "type" => "object",
      "required" => ["name", "tags"],
      "properties" => %{
        "name" => %{"type" => "string"},
        "tags" => %{
          "type" => "array",
          "items" => %{"type" => "string"}
        }
      }
    }

    assert ref_contents == content

    comp_path_items = get_in(schema, ["components", "pathItems"])

    comp_path_items_params = get_in(comp_path_items, ["CommonContent", "get", "parameters"])

    param = Enum.at(comp_path_items_params, 0)

    assert param["schema"] == %{
             "type" => "array",
             "items" => content
           }

    page_path_get = get_in(schema, ["paths", "/page", "get"])
    common_content_params = page_path_get["parameters"]

    assert length(common_content_params) == 1

    content_param = Enum.at(common_content_params, 0)

    assert content_param["name"] == "content" and
             content_param["in"] == "query"

    contents_path_post_request_body_schema =
      get_in(schema, [
        "paths",
        "/contents",
        "post",
        "requestBody",
        "content",
        "application/json",
        "schema"
      ])

    assert contents_path_post_request_body_schema == %{
             "type" => "array",
             "items" => content
           }

    contents_path_get = get_in(schema, ["paths", "/contents", "get"])
    common_content_params = contents_path_get["parameters"]

    assert length(common_content_params) == 1

    content_param = Enum.at(common_content_params, 0)

    assert content_param["name"] == "content" and
             content_param["in"] == "query"
  end

  test "duplicated defined object and the referenced object in a path item object" do
    yaml_str = """
      components:
        pathItems:
          Common:
            get:
              parameters:
                - name: lang
                  in: query
                  schema:
                    style: "integer"
      paths:
        /test1:
          $ref: "#/components/pathItems/Common"
          get:
            parameters:
              - name: l
                in: query
                schema:
                  style: "integer"
    """

    {:ok, data} = YamlElixir.read_from_string(yaml_str)

    root = ExJsonSchema.Schema.resolve(data)

    assert_raise Oasis.InvalidSpecError, ~r/Defined a duplicated field: `get` key/, fn ->
      Oasis.Spec.Utils.expand_ref(root)
    end

    yaml_str = """
      components:
        pathItems:
          Common:
            get:
              parameters:
                - name: lang
                  in: query
                  schema:
                    style: "integer"
      paths:
        /test1:
          get:
            parameters:
              - name: l
                in: query
                schema:
                  style: "integer"
          $ref: "#/components/pathItems/Common"
    """

    {:ok, data} = YamlElixir.read_from_string(yaml_str)

    root = ExJsonSchema.Schema.resolve(data)

    assert_raise Oasis.InvalidSpecError, ~r/Defined a duplicated field: `get` key/, fn ->
      Oasis.Spec.Utils.expand_ref(root)
    end

    yaml_str = """
      components:
        pathItems:
          Common:
            get:
              parameters:
                - name: lang
                  in: query
                  schema:
                    style: "integer"
          Common2:
            get:
              parameters:
                - name: lang2
                  in: query
                  schema:
                    style: "string"
      paths:
        /test1:
          get:
            parameters:
              - name: l
                in: query
                schema:
                  style: "integer"
          $ref: "#/components/pathItems/Common"
          $ref: "#/components/pathItems/Common2"
    """

    {:ok, data} = YamlElixir.read_from_string(yaml_str)

    root = ExJsonSchema.Schema.resolve(data)

    assert_raise Oasis.InvalidSpecError, ~r/Defined a duplicated field: `get` key/, fn ->
      Oasis.Spec.Utils.expand_ref(root)
    end
  end
end
