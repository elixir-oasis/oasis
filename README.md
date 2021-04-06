# Oasis

[![Coverage Status](https://coveralls.io/repos/github/elixir-oasis/oasis/badge.svg?branch=main)](https://coveralls.io/github/elixir-oasis/oasis?branch=main)

## Introduction

Background

> The [OpenAPI Specification](https://www.openapis.org/) (OAS) defines a standard, programming language-agnostic interface description for REST APIs, which allows both humans and computers to discover and understand the capabilities of a service without requiring access to source code, additional documentation, or inspection of network traffic. When properly defined via OpenAPI, a consumer can understand and interact with the remote service with a minimal amount of implementation logic. Similar to what interface descriptions have done for lower-level programming, the OpenAPI Specification removes guesswork in calling a service.

Oasis is:

Base on `Plug`'s implements, according to the OpenAPI Specification to generate server's router and the all well defined HTTP request handler(s), since the OAS defines a detailed collection of data types by [JSON Schema Specification](https://json-schema.org/), Oasis leverages this and focuses on the types conversion and validation to the parameters of the HTTP request.

* Maintain a standard REST APIs document(in YAML or JSON) via OpenAPI is in a high priority
* Generate the maintainable router and HTTP request handlers code by the defined document
* In general, we do not need to manually write OpenAPI definitions in Elixir
* Simplify the REST APIs to convert types and validate the parameters of the HTTP request
* More reference and communication to your REST APIs

## Installation

Add `oasis` as a dependency to your mix.exs

```elixir
def deps do
  [
    {:oasis, "~> 0.1"}
  ]
end
```

## Implements to OAS

Oasis does not cover the full OpenAPI specification, so far the implements contain:

* [Components Object](https://github.com/OAI/OpenAPI-Specification/blob/master/versions/3.1.0.md#componentsObject)
* [Paths Object](https://github.com/OAI/OpenAPI-Specification/blob/master/versions/3.1.0.md#pathsObject)
* [Path Item Object](https://github.com/OAI/OpenAPI-Specification/blob/master/versions/3.1.0.md#pathItemObject)
* [Operation Object](https://github.com/OAI/OpenAPI-Specification/blob/master/versions/3.1.0.md#operationObject)
* [Parameter Object](https://github.com/OAI/OpenAPI-Specification/blob/master/versions/3.1.0.md#parameterObject)
* [Request Body Object](https://github.com/OAI/OpenAPI-Specification/blob/master/versions/3.1.0.md#requestBodyObject)
* [Media Type Object](https://github.com/OAI/OpenAPI-Specification/blob/master/versions/3.1.0.md#mediaTypeObject)
* [Header Object](https://github.com/OAI/OpenAPI-Specification/blob/master/versions/3.1.0.md#headerObject)
* [Reference Object](https://github.com/OAI/OpenAPI-Specification/blob/master/versions/3.1.0.md#referenceObject)
* [Schema Object](https://github.com/OAI/OpenAPI-Specification/blob/master/versions/3.1.0.md#schemaObject)
* [Security Scheme Object](https://github.com/OAI/OpenAPI-Specification/blob/master/versions/3.1.0.md#securitySchemeObject)
  * Bearer Authentication, please see `Oasis.Plug.BearerAuth` for details.

## OAS Specification Extensions

Oasis be with the following specification extensions to accommodate the use cases:

* `"x-oasis-name-space"`, optional, use this field to define the generated Elixir module's name space in [Operation Object](https://github.com/OAI/OpenAPI-Specification/blob/master/versions/3.1.0.md#operationObject) or [Paths Object](https://github.com/OAI/OpenAPI-Specification/blob/master/versions/3.1.0.md#pathsObject), defaults to `Oasis.Gen`.
* `"x-oasis-router"`, optional, use this field to define the generated Elixir router module's alias in [Paths Object](https://github.com/OAI/OpenAPI-Specification/blob/master/versions/3.1.0.md#pathsObject), defaults to `Router`.
* `"x-oasis-key-to-assigns"`, optional, after the verification of the token, the original data will be stored into this provided field (as an atom) of the `conn.assigns` for the next accessing, if not defined it, there won't do any process for the verified original data, please see `Oasis.Plug.BearerAuth` for details.

## How to use

### Prepare YAML or JSON specification

First, write your API document refer the OpenAPI Specification(see [reference](#reference) for details), we build Oasis with the version [3.1.0](http://spec.openapis.org/oas/v3.1.0) of the OAS, as usual, the common use case should be covered for the version `3.0.*` of the OAS.

Here is a minimum specification for an example in YAML, we save it as "petstore-mini.yaml" in this tutorial.

```yaml
openapi: "3.1.0"
info:
  title: Petstore Mini
paths:
  /pets:
    get:
      parameters:
        - name: tags
          in: query
          required: false
          schema:
            type: array
            items:
              type: string
        - name: limit
          in: query
          requried: false
          schema:
            type: integer
            format: int32
      response:
        '200':
          content:
            application/json:
              schema:
                type: array
                items:
                  $ref: '#/components/schemas/Pet'
    post:
      operationId: addPet
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/NewPet'
      response:
        '200':
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Pet'

  /pets/{id}:
    get:
      operationId: find pet by id
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: integer
            format: int64
      response:
        '200':
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Pet'
components:
  schemas:
    Pet:
      allOf:
        - $ref: '#/components/schemas/NewPet'
        - type: object
          required:
          - id
          properties:
            id:
              type: integer
              format: int64

    NewPet:
      type: object
      required:
        - name
      properties:
        name:
          type: string
        tag:
          type: string
```

### Run mix task

And then we run the following mix task to generate the corresponding files:

```
mix oas.gen.plug --file path/to/petstore-mini.yaml
```

We will see these output:

```
Generates Router and Plug modules from OAS
* creating lib/oasis/gen/router.ex
* creating lib/oasis/gen/pre_find_pet_by_id.ex
* creating lib/oasis/gen/find_pet_by_id.ex
* creating lib/oasis/gen/pre_add_pet.ex
* creating lib/oasis/gen/add_pet.ex
* creating lib/oasis/gen/pre_get_pets.ex
* creating lib/oasis/gen/get_pets.ex
```

The arguments of `oas.gen.plug` mix task:

* `--file`, required, the completed path to the specification file in YAML or JSON format.
* `--router`, optional, the generated router's module alias, by default it is `Router` (the full module name is `Oasis.Gen.Router` by default), for example we set `--router Hello.MyRouter` meanwhile there is no other special name space defined, the final router module is `Oasis.Gen.Hello.MyRouter` in `/lib/oasis/gen/hello/my_router.ex` path.
* `--name-space`, optional, the generated all modules' name space, by default it is `Oasis.Gen`, this argument will always override the name space from the input `--file` if any `"x-oasis-name-space"` field(s) defined.

### Special instructions

#### Name Plug's handler

Refer the OAS, the `operationId` field of [Operation Object](https://github.com/OAI/OpenAPI-Specification/blob/master/versions/3.1.0.md#operationObject) is not required, but it should be unique among all operations described in the API if `operationId` field exists.

   * When use this field, Oasis will use it to construct the generated module alias and the file name of ".ex" file, e.g. see the above `find_pet_by_id.ex` file with `Oasis.Gen.FindPetById` module name.
   * When not use this filed, Oasis will combine the HTTP verb with the URL to generate the module alias and the file name of ".ex" file, e.g. see the above `get_pets.ex` file with `Oasis.Gen.GetPets` module name.

#### Generated code to folder

The generated codes are always put in the `lib` directory of your application root path, because they need to be integrated into your application in runtime.

#### Custom name space of generated modules

By default, the name space of the generated module is `Oasis.Gen` and its folder path is `lib/oasis/gen`, but we can custom it use these ways:

1. As a final global definition when run `oas.gen.plug` mix task, input `--name-space` argument to set this, this argument always overrides all name space even we have some sections of document have special definition (via `"x-oasis-name-space"`), for example:

  ```
  mix oas.gen.plug --file path/to/petstore-mini.yaml --name-space My.Petstore
  Generates Router and Plug modules from OAS
  * creating lib/my/petstore/router.ex
  * creating lib/my/petstore/pre_find_pet_by_id.ex
  * creating lib/my/petstore/find_pet_by_id.ex
  * creating lib/my/petstore/pre_add_pet.ex
  * creating lib/my/petstore/add_pet.ex
  * creating lib/my/petstore/pre_get_pets.ex
  * creating lib/my/petstore/get_pets.ex
  ```

  Now, we can see the generation folder path is `lib/my/petstore`, let's open the `get_pets.ex` file, the module name changed from `Oasis.Gen.GetPets` to `My.Petstore.GetPets`.

2. Use `"x-oasis-name-space"` in the OAS's [Operation Object](https://github.com/OAI/OpenAPI-Specification/blob/master/versions/3.1.0.md#operationObject), for example, add this newline `x-oasis-name-space: Common.Api` as below:

  ```yaml
    paths:
      /pets:
        get:
          x-oasis-name-space: Common.Api
          parameters:
            - name: tags
              ...
        post:
          ...
      /pets/{id}:
        ...
  ```

  Run again, please note this time no `--name-space` argument.

  ```
  mix oas.gen.plug --file path/to/petstore-mini.yaml
  Generates Router and Plug modules from OAS
  * creating lib/oasis/gen/router.ex
  * creating lib/oasis/gen/pre_find_pet_by_id.ex
  * creating lib/oasis/gen/find_pet_by_id.ex
  * creating lib/oasis/gen/pre_add_pet.ex
  * creating lib/oasis/gen/add_pet.ex
  * creating lib/common/api/pre_get_pets.ex
  * creating lib/common/api/get_pets.ex
  ```

  We can see `pre_get_pets.ex` and `get_pets.ex` files are moved into the expected path, and their module names are `Common.Api.GetPets` and `Common.Api.PreGetPets`, other operations do not define any `"x-oasis-name-space"` field, so they still use the default one `Oasis.Gen`.

3. Use `"x-oasis-name-space"` in the OAS's [Paths Object](https://github.com/OAI/OpenAPI-Specification/blob/master/versions/3.1.0.md#pathsObject), this use case as a global setting and can archive it in the document under the file version management, for example, add this newline `x-oasis-name-space: Common.Api` as below:

  ```yaml
    paths:
      x-oasis-name-space: Common.Api
      /pets:
        get:
          parameters:
            - name: tags
              ...
        post:
          ...
      /pets/{id}:
        ...
  ```

  Run again, please note this time no `--name-space` argument, and the GET operation of the "/pets" path is no "x-oasis-name-space" either.

  ```
  mix oas.gen.plug --file path/to/petstore-mini.yaml
  Generates Router and Plug modules from OAS
  * creating lib/common/api/router.ex
  * creating lib/common/api/pre_find_pet_by_id.ex
  * creating lib/common/api/find_pet_by_id.ex
  * creating lib/common/api/pre_add_pet.ex
  * creating lib/common/api/add_pet.ex
  * creating lib/common/api/pre_get_pets.ex
  * creating lib/common/api/get_pets.ex
  ```

We can see all generated files are moved into the expected path, and all modules' name start with `Common.Api`.

Summarize about the name space of generated module:

  1. The optional `--name-space` argument to the `mix oas.gen.plug` command line is in the highest priority to set the name space;

  2. We can use `"x-oasis-name-space"` extension field of the OAS's [Paths Object](https://github.com/OAI/OpenAPI-Specification/blob/master/versions/3.1.0.md#pathsObject) as a global naming if we want to save and maintain it in the document, but this case may be overridden by #1.

  3. We also can set `"x-oasis-name-space"` extension field in each [Operation Object](https://github.com/OAI/OpenAPI-Specification/blob/master/versions/3.1.0.md#operationObject) in the document, but this case may be overridden by #1 or #2.

#### HTTP request handler files in pairs

The generated HTTP request handler files are named in pairs, one is `pre_operation.ex`, and another is `operation.ex`, the name beginning with **`pre_`** file is in charge of converting and validating the parameters of each HTTP request definition, the content of this file will be updated according to the section of the document changes or Oasis upgrade in the future, so we ***CAN NOT*** write any business logic in this file; another file is only created in the first time of generation as long as this file does not exist, this is a common `Plug` module which is after the defined preprocessor by `Plug`'s pipeline, we need to fill in business logic in here.

```
mix oas.gen.plug --file path/to/petstore-mini.yaml
Generates Router and Plug modules from OAS
* creating lib/oasis/gen/router.ex
* creating lib/oasis/gen/pre_find_pet_by_id.ex
* creating lib/oasis/gen/find_pet_by_id.ex
* creating lib/oasis/gen/pre_add_pet.ex
* creating lib/oasis/gen/add_pet.ex
* creating lib/oasis/gen/pre_get_pets.ex
* creating lib/oasis/gen/get_pets.ex
```

#### Integration

After the above generation, let's integrate it, assume the generated router is `Oasis.Gen.Router`, we can use it in the `Plug`'s adapter like this:

```elixir
Plug.Adapters.Cowboy.child_spec(
  scheme: :http,
  plug: Oasis.Gen.Router,
  options: [
    port: port
  ]
)
```

Or we can plug this router into the existence router module like this:

```elixir
defmodule MyExistenceRouter do
  use Plug.Router

  plug(Oasis.Gen.Router)

  plug(:match)
  plug(:dispatch)

  # other

end
```

Please note that the added line of `plug(Oasis.Gen.Router)` is before the line of `plug(:match)`.

## Todo

1. The Specification contains XML object is not supported so far.
2. May add mix task to generate `Phoenix`'s style code.
3. Make document more clear.
4. There are still some details maybe not implement(or bug) from the OAS, please create an issue or a PR for tracking, thanks in advanced :)

## Reference

1. The official OpenAPI Specification v3: [Github](https://github.com/OAI/OpenAPI-Specification/blob/master/versions/3.1.0.md) | [Official Web Site](http://spec.openapis.org/oas/v3.1.0)
2. [JSON Schema Reference](https://json-schema.org/understanding-json-schema/reference/)
