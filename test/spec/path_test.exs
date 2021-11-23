defmodule Oasis.Spec.PathTest do
  use ExUnit.Case

  import Oasis.Test.Support.Spec

  alias Oasis.Spec.{Path, Utils}

  test "format url" do
    url = "/{a}"
    assert Path.format_url(url) == "/:a"

    url = "/a/{b}/c"
    assert Path.format_url(url) == "/a/:b/c"

    url = "/a/{b}/{c}/d"
    assert Path.format_url(url) == "/a/:b/:c/d"

    url = "/a/{b}/c/{d}/{e}"
    assert Path.format_url(url) == "/a/:b/c/:d/:e"

    url = "/a/b/c"
    assert Path.format_url(url) == "/a/b/c"

    url = "/{a}/{b}/{c}"
    assert Path.format_url(url) == "/:a/:b/:c"

    url = "/a.{format}"
    assert Path.format_url(url) == "/a.:format"

    url = "/users/{.id}"
    assert Path.format_url(url) == "/users/:id"

    url = "/users/{.id*}"
    assert Path.format_url(url) == "/users/:id"

    url = "/users/{;id}"
    assert Path.format_url(url) == "/users/:id"

    url = "/users/{;id*}"
    assert Path.format_url(url) == "/users/:id"
  end

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
          description: "test page desc"
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
      |> Utils.expand_ref()
      |> Path.build()

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
      Path.build(root)
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
                   Path.build(root)
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
                   Path.build(root)
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
      Path.build(root)
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
              - name: Token
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
      |> Path.build()

    parameters = root.schema["paths"]["/content"]["get"]["parameters"]

    header = parameters["header"]

    # only `token` parameter
    assert length(header) == 1

    [param_token] = header
    assert param_token["name"] == "token" and param_token["in"] == "header"

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
      |> Path.build()

    query = root.schema["paths"]["/content/:id"]["get"]["parameters"]["query"]

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
                required: true
                schema:
                  type: integer
    """

    root = yaml_to_json_schema(yaml_str)

    assert_raise Oasis.InvalidSpecError,
                 ~r(MUST correspond to a template expression occurring within the path: `/content/{id}`),
                 fn ->
                   Path.build(root)
                 end

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
                 ~r(Define a parameter object in path named as: `typo_id`, but missing explicitly define this parameter be with `required: true` in the specification),
                 fn ->
                   Path.build(root)
                 end
  end

  test "input empty parameter name" do
    yaml_str = """
      paths:
        /content/{id}:
          get:
            parameters:
              - name: "    "
                in: query
                schema:
                  type: string
    """

    root = yaml_to_json_schema(yaml_str)

    assert_raise Oasis.InvalidSpecError,
                 ~r(The name of the parameter is missing in the path: `/content/{id}`),
                 fn ->
                   Path.build(root)
                 end
  end

  test "input invalid parameter name" do
    yaml_str = """
      paths:
        /content/{id}:
          get:
            parameters:
              - name:
                  value: "test"
                in: query
                schema:
                  type: string
    """

    root = yaml_to_json_schema(yaml_str)

    assert_raise Oasis.InvalidSpecError,
                 ~r(The name of the parameter expect to be a string, but got `%{"value" => "test"}` in the path: `/content/{id}`),
                 fn ->
                   Path.build(root)
                 end
  end

  test "missing parameter name" do
    yaml_str = """
      paths:
        /content/{id}:
          get:
            parameters:
              - in: query
                schema:
                  type: string
    """

    root = yaml_to_json_schema(yaml_str)

    assert_raise Oasis.InvalidSpecError,
                 ~r(The name of the parameter is missing in the path: `/content/{id}`),
                 fn ->
                   Path.build(root)
                 end
  end

  test "unsupport trace http verb" do
    yaml_str = """
      paths:
        /hello:
          trace:
            parameters:
              - name: username
                in: query
                schema:
                  type: string
    """

    root = yaml_to_json_schema(yaml_str)

    assert_raise Oasis.InvalidSpecError,
                 ~r(Not Support `trace` http method from `/hello` path),
                 fn ->
                   Path.build(root)
                 end
  end

  test "x-oasis-name-space in paths and operation" do
    yaml_str = """
      paths:
        x-oasis-name-space: Common
        /content:
          get:
            x-oasis-name-space: Specv1
            operationId: content
            parameters:
              - name: Token
                in: header
                schema:
                  type: string
              - name: accept
                in: query
                schema:
                  type: integer
    """

    %{schema: schema} = yaml_to_json_schema(yaml_str) |> Path.build()

    paths = schema["paths"]
    assert paths["x-oasis-name-space"] == "Common"
    assert paths["/content"]["get"]["x-oasis-name-space"] == "Specv1"
  end

  test "x-oasis-router in paths object" do
    yaml_str = """
      paths:
        x-oasis-router: MyRouter
        /hello:
          get:
            operationId: SayHello
            parameters:
              - name: username
                in: query
                schema:
                  type: string
    """

    %{schema: schema} = yaml_to_json_schema(yaml_str) |> Path.build()
    paths = schema["paths"]
    assert paths["x-oasis-router"] == "MyRouter"
  end

  test "components requestBodies" do
    yaml_str = """
      paths:
        /refresh:
          post:
            requestBody:
              $ref: '#/components/requestBodies/RefreshTokenForm'

      components:
        schemas:
          uuid:
            type: string
          RefreshTokenForm:
            type: object
            properties:
              refresh_token:
                $ref: '#/components/schemas/uuid'
            required:
              - refresh_token

        requestBodies:
          RefreshTokenForm:
            content:
              application/json:
                schema:
                  $ref: '#/components/schemas/RefreshTokenForm'
    """
    %{schema: schema} = yaml_to_json_schema(yaml_str) |> Utils.expand_ref() |> Path.build()
    components = schema["components"]
    content_schema = get_in(components, ["requestBodies", "RefreshTokenForm", "content", "application/json", "schema"])
    assert content_schema["type"] == "object" and content_schema["required"] == ["refresh_token"]

    paths = schema["paths"]
    content_schema = get_in(paths, ["/refresh", "post", "requestBody", "content", "application/json", "schema"])
    assert content_schema["type"] == "object" and content_schema["required"] == ["refresh_token"]
  end

  test "security bearer auth in global" do
    yaml_str = """
      paths:
        /user:
          get:
            parameters:
              - name: id
                in: query
                schema:
                  type: string
      components:
        securitySchemes:
          bearerAuth:
            type: http
            scheme: bearer
            x-oasis-key-to-assigns: id

      security:
        - bearerAuth: []
    """

    %{schema: schema} = yaml_to_json_schema(yaml_str) |> Path.build()

    security_schemes = Oasis.Spec.Security.security_schemes(schema)

    assert Oasis.Spec.Security.build(schema, security_schemes) ==
      [{"bearerAuth", %{"scheme" => "bearer", "type" => "http", "x-oasis-key-to-assigns" => "id"}}]

    schema = Map.delete(schema, "security")

    assert Oasis.Spec.Security.build(schema, security_schemes) == nil
  end

  test "security bearer auth in operation" do
    yaml_str = """
      paths:
        /user:
          get:
            parameters:
              - name: id
                in: query
                schema:
                  type: string
            security:
              - bearerAuth: []
        /register:
          post:
            requestBody:
              $ref: '#/components/requestBodies/RegisterForm'
            security:
              - basicAuth: []

      components:
        securitySchemes:
          bearerAuth:
            type: http
            scheme: bearer
            x-oasis-key-to-assigns: id
          basicAuth:
            type: http
            scheme: basic
        requestBodies:
          RegisterForm:
            type: object
            properties:
              username:
                type: string
            required:
              - username
    """

    %{schema: schema} = yaml_to_json_schema(yaml_str) |> Utils.expand_ref() |> Path.build()

    security_schemes = Oasis.Spec.Security.security_schemes(schema)

    paths = schema["paths"]

    operation = paths["/user"]["get"]

    assert Oasis.Spec.Security.build(operation, security_schemes) ==
      [{"bearerAuth", %{"scheme" => "bearer", "type" => "http", "x-oasis-key-to-assigns" => "id"}}]

    operation = paths["/register"]["post"]
    # not supported yet
    assert Oasis.Spec.Security.build(operation, security_schemes) == nil
  end

  test "multiple security schemes" do
    yaml_str = """
      paths:
        /user:
          get:
            parameters:
              - name: id
                in: query
                schema:
                  type: string
      components:
        securitySchemes:
          apiKeyAuth:
            type: apiKey
            name: access_key
            in: header
          bearerAuth:
            type: http
            scheme: bearer
            x-oasis-key-to-assigns: verified
          basicAuth:
            type: http
            scheme: basic

      security:
        - bearerAuth: []
        - basicAuth: []
        - apiKeyAuth: []
    """

    %{schema: schema} = yaml_to_json_schema(yaml_str) |> Path.build()

    security_schemes = Oasis.Spec.Security.security_schemes(schema)

    assert Oasis.Spec.Security.build(schema, security_schemes) ==
      [{"bearerAuth", %{"scheme" => "bearer", "type" => "http", "x-oasis-key-to-assigns" => "verified"}}]
  end

end
