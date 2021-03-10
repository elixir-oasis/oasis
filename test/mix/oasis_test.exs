defmodule Mix.OasisTest do
  use ExUnit.Case, async: true

  test "name space" do
    {default_path, default_name_space} = Mix.Oasis.name_space(nil)

    assert default_path == "lib/oasis/gen" and
             default_name_space == Oasis.Gen

    input = "My.App"
    {path, name_space} = Mix.Oasis.name_space(input)

    assert path == "lib/my/app" and
             name_space == My.App

    input = "my123"
    {path, name_space} = Mix.Oasis.name_space(input)

    assert path == "lib/my123" and
             name_space == :"Elixir.my123"

    input = "My.APP"
    {path, name_space} = Mix.Oasis.name_space(input)

    assert path == "lib/my/app" and
             name_space == My.APP
  end

  test "module name" do
    name = "My.App.ModuleName"
    {module_name, file_name} = Mix.Oasis.module_name(name)

    assert module_name == "MyAppModuleName" and
             file_name == "my_app_module_name.ex"

    name = "My...App.ModuleName"
    {module_name, file_name} = Mix.Oasis.module_name(name)

    assert module_name == "MyAppModuleName" and
             file_name == "my_app_module_name.ex"

    name = "my/app"
    {module_name, file_name} = Mix.Oasis.module_name(name)

    assert module_name == "My/app" and
             file_name == "my/app.ex"

    name = "TestFlight"
    {module_name, file_name} = Mix.Oasis.module_name(name)

    assert module_name == "TestFlight" and
             file_name == "test_flight.ex"

    assert module_name == "TestFlight" and
             file_name == "test_flight.ex"

    router = %{operation_id: "GetUserInfo"}
    {module_name, file_name} = Mix.Oasis.module_name(router)

    assert module_name == "GetUserInfo" and
             file_name == "get_user_info.ex"

    router = %{http_verb: :get, url: "/user/:id"}
    {module_name, file_name} = Mix.Oasis.module_name(router)

    assert module_name == "GetUserId" and
             file_name == "get_user_id.ex"

    # `operation_id` in high priority compares to `http_verb` with `url` if
    # both exists

    router = %{operation_id: "SayHi", http_verb: :post, url: "/hi"}
    {module_name, file_name} = Mix.Oasis.module_name(router)

    assert module_name == "SayHi" and
             file_name == "say_hi.ex"
  end

  test "Mix.Oasis.new/2 with request body and parameters" do
    post = %{
      "description" => "Creates a new pet in the store. Duplicates are allowed",
      "operationId" => "addPet",
      "parameters" => %{},
      "requestBody" => %{
        "content" => %{
          "application/json" => %{
            "schema" => %{
              "properties" => %{
                "name" => %{"type" => "string"},
                "tag" => %{"type" => "string"}
              },
              "required" => ["name"],
              "type" => "object"
            }
          },
          "application/x-www-form-urlencoded" => %{
            "schema" => %{
              "properties" => %{
                "name" => %{"type" => "string"},
                "fav_number" => %{"type" => "integer", "minimum" => 1, "maximum" => 3}
              },
              "required" => ["name", "fav_number"],
              "type" => "object"
            }
          }
        },
        "description" => "Pet to add to the store",
        "required" => true
      }
    }

    get = %{
      "parameters" => %{
        "query" => [
          %{
            "in" => "query",
            "name" => "id",
            "required" => true,
            "schema" => %{
              "items" => %{"type" => "string"},
              "type" => "array"
            }
          }
        ]
      }
    }

    paths_spec = %{
      "paths" => %{
        "/my_post" => %{
          "post" => post,
          "get" => get
        }
      }
    }

    files = Mix.Oasis.new(paths_spec, [])

    assert length(files) == 5

    [router_file | plug_files] = files

    {:eex, file_path, _router_template_file_name, router_module_name, %{routers: binding_pre_routers}} = router_file

    assert file_path == "lib/oasis/gen/router.ex" and router_module_name == Oasis.Gen.Router and

    assert length(binding_pre_routers) == 2

    Enum.map(plug_files, fn
      {_, file_path1, "pre_plug.ex", Oasis.Gen.PreAddPet, router} ->

        assert file_path1 == "lib/oasis/gen/pre_add_pet.ex" and router.http_verb == "post" and
          router.operation_id == "addPet"

        body_schema = router.body_schema

        assert router.query_schema == nil and body_schema != nil

        schema = body_schema["content"]["application/json"]
        assert is_struct(schema, ExJsonSchema.Schema.Root)

        assert ExJsonSchema.Validator.valid?(schema, %{"name" => "test-name"})
        assert ExJsonSchema.Validator.valid?(schema, %{"tag" => "test-tag"}) == false

        schema = body_schema["content"]["application/x-www-form-urlencoded"]
        assert is_struct(schema, ExJsonSchema.Schema.Root)

        assert ExJsonSchema.Validator.valid?(schema, %{"name" => "test-name", "fav_number" => 1}) == true
        assert ExJsonSchema.Validator.valid?(schema, %{"fav_number" => 1}) == false
        assert ExJsonSchema.Validator.valid?(schema, %{"name" => "test-name", "fav_number" => 10}) == false

      {_, file_path2, "plug.ex", Oasis.Gen.AddPet, router} ->

        assert file_path2 == "lib/oasis/gen/add_pet.ex" and router.http_verb == "post" and
          router.operation_id == "addPet"

      {_, file_path3, "pre_plug.ex", Oasis.Gen.PreGetMyPost, router} ->

        assert file_path3 == "lib/oasis/gen/pre_get_my_post.ex" and router.http_verb == "get" and
          router.operation_id == nil

        assert router.query_schema != nil and router.body_schema == nil

        %{"id" => %{"schema" => schema}} = router.query_schema

        assert ExJsonSchema.Validator.valid?(schema, 1) == false
        assert ExJsonSchema.Validator.valid?(schema, ["a", "b", "c"]) == true

      {_, file_path4, "plug.ex", Oasis.Gen.GetMyPost, router} ->

        assert file_path4 == "lib/oasis/gen/get_my_post.ex" and router.http_verb == "get" and
          router.operation_id == nil
    end)
  end

  test "Mix.Oasis.new/2 invalid spec" do
    spec = %{
      "components" => %{
        "schemas" => %{
           "User" => %{
             "properties" => %{
               "id" => %{"format" => "int64", "type" => "integer"},
               "name" => %{"type" => "string"}
             },
             "required" => ["id", "name"],
             "type" => "object"
            }
          }
        },
      "info" => %{"title" => "Test API", "version" => "1.0.0"},
      "openapi" => "3.1.0"
    }

    assert_raise RuntimeError, ~r/could not find any paths defined/, fn ->
      Mix.Oasis.new(spec, [])
    end
  end

  test "Mix.Oasis.new/2 multi urls" do
    operation1 = %{
      "parameters" => %{
        "path" => [
          %{
            "description" => "ID of pet to delete",
            "in" => "path",
            "name" => "id",
            "required" => true,
            "schema" => %{"format" => "int64", "type" => "integer"}
          }
        ],
        "query" => [
          %{
            "description" => "tags to filter by",
            "in" => "query",
            "name" => "tags",
            "required" => false,
            "schema" => %{
              "items" => %{"type" => "string"},
              "type" => "array"
            },
            "style" => "form"
          }
        ]
      },
      "operationId" => "delete_pet"
    }

    operation2 = %{
      "parameters" => %{
        "header" => [
          %{
            "name" => "token",
            "required" => true,
            "schema" => %{"type" => "string"}
          },
          %{
            "name" => "appid",
            "required" => true,
            "schema" => %{"type" => "string"}
          }
        ],
        "cookie" => [
          %{
            "name" => "session_id",
            "required" => true,
            "schema" => %{"type" => "integer"}
          }
        ]
      }
    }

    paths_spec = %{
      "paths" => %{
        "/queryPet" => %{
          "get" => operation2,
          "put" => operation2
        },
        "/delete_pet" => %{
          "delete" => operation1
        }
      }
    }

    files = Mix.Oasis.new(paths_spec, [router: "my_test_router"])

    assert length(files) == 7

    [router_file | plug_files] = files

    {:eex, file_path, _router_template_file_name, router_module_name, %{routers: binding_pre_routers}} = router_file

    assert file_path == "lib/oasis/gen/my_test_router.ex" and
      router_module_name == Oasis.Gen.MyTestRouter

    assert length(binding_pre_routers) == 3

    # the defined router(s) in "router.ex" file are sorted by url in asc order
    urls = Enum.map(binding_pre_routers, fn(router) -> router.url end) 

    assert urls == ["/delete_pet", "/queryPet", "/queryPet"]

    Enum.map(plug_files, fn
      {_, file_path, "pre_plug.ex", Oasis.Gen.PrePutQueryPet, router} ->
        assert file_path == "lib/oasis/gen/pre_put_query_pet.ex" and router.http_verb == "put"
        assert router.header_schema != nil and router.cookie_schema != nil

        %{"session_id" => %{"schema" => schema}} = router.cookie_schema
        assert ExJsonSchema.Validator.valid?(schema, 1) == true
        assert ExJsonSchema.Validator.valid?(schema, "abc") == false

        %{"token" => %{"schema" => token_schema}, "appid" => %{"schema" => appid_schema}} = router.header_schema
        assert ExJsonSchema.Validator.valid?(token_schema, "1") == true
        assert ExJsonSchema.Validator.valid?(token_schema, 1) == false

        assert ExJsonSchema.Validator.valid?(appid_schema, "abc") == true
        assert ExJsonSchema.Validator.valid?(appid_schema, 100) == false

      {_, file_path, "plug.ex", Oasis.Gen.PutQueryPet, router} ->
        assert file_path == "lib/oasis/gen/put_query_pet.ex" and router.http_verb == "put"

        assert router.plug_module == Oasis.Gen.PutQueryPet
        assert router.pre_plug_module == Oasis.Gen.PrePutQueryPet

      {_, file_path, "pre_plug.ex", Oasis.Gen.PreGetQueryPet, router} ->
        assert file_path == "lib/oasis/gen/pre_get_query_pet.ex" and router.http_verb == "get"
        assert router.header_schema != nil and router.cookie_schema != nil

      {_, file_path, "plug.ex", Oasis.Gen.GetQueryPet, router} ->
        assert file_path == "lib/oasis/gen/get_query_pet.ex" and router.http_verb == "get"
        assert router.header_schema != nil and router.cookie_schema != nil

      {_, file_path, "pre_plug.ex", Oasis.Gen.PreDeletePet, router} ->
        assert file_path == "lib/oasis/gen/pre_delete_pet.ex" and router.http_verb == "delete"
        assert router.path_schema != nil and router.query_schema != nil

        %{"id" => %{"schema" => schema}} = router.path_schema
        assert ExJsonSchema.Validator.valid?(schema, 1) == true
        assert ExJsonSchema.Validator.valid?(schema, "1") == false

        %{"tags" => %{"schema" => schema}} = router.query_schema
        assert ExJsonSchema.Validator.valid?(schema, ["1", "2", "3"]) == true
        assert ExJsonSchema.Validator.valid?(schema, "abc") == false

      {_, file_path, "plug.ex", Oasis.Gen.DeletePet, router} ->
        assert file_path == "lib/oasis/gen/delete_pet.ex" and router.http_verb == "delete"
        assert router.path_schema != nil and router.query_schema != nil

        assert router.pre_plug_module == Oasis.Gen.PreDeletePet
        assert router.plug_module == Oasis.Gen.DeletePet
    end)
  end

  test "Mix.Oasis.new/2 optional options" do
    paths_spec = %{
      "paths" => %{
        "/say_hello" => %{
          "get" => %{
            "parameters" => %{
              "query" => [
                %{
                  "name" => "username",
                  "required" => true,
                  "schema" => %{"type" => "string"}
                }
              ]
            },
            "operationId" => "hello",
            "name_space" => "Wont.Use"
          }
        }
      }
    }

    [router | plugs] = Mix.Oasis.new(paths_spec, [name_space: "Try.MyOpenAPI"])

    {_, router_file_path, _, router_module_name, binding} = router

    assert router_file_path == "lib/try/my_open_api/router.ex"
    assert router_module_name == Try.MyOpenAPI.Router
    assert length(binding.routers) == 1

    [pre_plug_file, plug_file] = plugs

    {_, path, template, module, binding} = pre_plug_file
    assert path == "lib/try/my_open_api/pre_hello.ex"
    assert template == "pre_plug.ex"
    assert module == Try.MyOpenAPI.PreHello
    assert binding.pre_plug_module == Try.MyOpenAPI.PreHello
    assert binding.plug_module == Try.MyOpenAPI.Hello

    {_, path, template, module, binding} = plug_file
    assert path == "lib/try/my_open_api/hello.ex"
    assert template == "plug.ex"
    assert module == Try.MyOpenAPI.Hello
    assert binding.pre_plug_module == Try.MyOpenAPI.PreHello
    assert binding.plug_module == Try.MyOpenAPI.Hello

    [router | plugs] = Mix.Oasis.new(paths_spec, [name_space: "Try.Test.OpenAPI2", router: "SuperRouter"])

    {_, router_file_path, _, router_module_name, binding} = router
    assert router_file_path == "lib/try/test/open_api2/super_router.ex"
    assert router_module_name == Try.Test.OpenAPI2.SuperRouter
    assert length(binding.routers) == 1

    [pre_plug_file, plug_file] = plugs

    {_, path, template, module, binding} = pre_plug_file
    assert path == "lib/try/test/open_api2/pre_hello.ex"
    assert template == "pre_plug.ex"
    assert module == Try.Test.OpenAPI2.PreHello
    assert binding.pre_plug_module == Try.Test.OpenAPI2.PreHello
    assert binding.plug_module == Try.Test.OpenAPI2.Hello

    {_, path, template, module, binding} = plug_file
    assert path == "lib/try/test/open_api2/hello.ex"
    assert template == "plug.ex"
    assert module == Try.Test.OpenAPI2.Hello
    assert binding.pre_plug_module == Try.Test.OpenAPI2.PreHello
    assert binding.plug_module == Try.Test.OpenAPI2.Hello
  end

end
