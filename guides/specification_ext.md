# Specification Extensions

Oasis be with the following [specification extensions](https://github.com/OAI/OpenAPI-Specification/blob/master/versions/3.1.0.md#specificationExtensions) to accommodate some use cases in the defined YAML or JSON specification file.

## Module Name Space

`"x-oasis-name-space"`, optional, use this field to define the generated Elixir module's name space in the following objects, defaults to `Oasis.Gen`:
  * [Paths Object](https://github.com/OAI/OpenAPI-Specification/blob/master/versions/3.1.0.md#pathsObject)
  * [Operation Object](https://github.com/OAI/OpenAPI-Specification/blob/master/versions/3.1.0.md#operationObject)
  * [Security Scheme Object](https://github.com/OAI/OpenAPI-Specification/blob/master/versions/3.1.0.md#securitySchemeObject)

### Example

#### In Paths Object

Here, define this field in [Paths Object](https://github.com/OAI/OpenAPI-Specification/blob/master/versions/3.1.0.md#pathsObject)
as a global name space to the all generated modules when when no other special definitions, in the below example
there will use "Hello.Petstore" to the module naming prefix alias of the all generated modules.

```YAML
paths:
  /pets:
    get:
      ...
  /pets/{id}:
    get:
      ...
    delete:
      ...
  x-oasis-name-space: Hello.Petstore
```

#### In Operation Object

Here, define this field in [Operation Object](https://github.com/OAI/OpenAPI-Specification/blob/master/versions/3.1.0.md#operationObject),
it only affect to a operation related generated modules when no other special definitions, in the below example
there will use "Petstore.Api" to the module naming prefix alias of the generated related modules to handler request of "/pets" in HTTP GET verb, other generated modules
will use `Oasis.Gen` as the default.

```YAML
paths:
  /pets:
    get:
      x-oasis-name-space: Petstore.Api
      operationId: list pets
      ...
  /pets/{id}:
    get:
      ...
    delete:
      ...
```

#### In Security Scheme Object

Here, define this field in [Security Scheme Object](https://github.com/OAI/OpenAPI-Specification/blob/master/versions/3.1.0.md#securitySchemeObject),
it only affect to the generated bearer token module when no other special definitions, in the below example
there will use "Petstore.MyToken" to the "helloBearerAuth" module (its full module name is "Petstore.MyToken.HelloBearerAuth").

```YAML
paths:
  /pets:
    get:
      security:
        - helloBearerAuth: []

components:
  securitySchemes:
    helloBearerAuth: # arbitrary name for the security scheme
      scheme: bearer
      type: http
      x-oasis-name-space: Petstore.MyToken
```

### Summary

`"x-oasis-name-space"` can be used at the same time for the above scenarios, but the defined in Security Scheme Object will override the defined in Operation Object for
the generated bearer token module, the defined in Operation Object will override the defined in Paths Object for the corresponding operation related modules.

We also can set a global name space when run `mix oas.gen.plug` with the `--name-space` argument, it applies to all generated modules and always override the defined from
the specification file.

Follow Elixir's module naming conventions, each dot(".") of module name will split the alias as a directory in lowercase to concat the full directory path,
and also we do not validate the value of this field in a strict mode, so please follow the usual naming conventions as much as possible.

## Router Module Alias

`"x-oasis-router"`, optional, use this field to define the generated Elixir router module's alias in [Paths Object](https://github.com/OAI/OpenAPI-Specification/blob/master/versions/3.1.0.md#pathsObject), defaults to `Router`.

### Example

When use an OpenAPI Specification to run `mix oas.gen.plug`, there will generate a router file and some corresponding operation handler modules files(in pair),
the router file packages all defined HTTP router(s) to each hanlder(s), we can custom the module name of the router file by the `"x-oasis-router"` and
`"x-oasis-name-space"` in the specification file, without other special name space defined, the following example defines the module full name space of the router
module is "Oasis.Gen.HelloRouter".

```YAML
paths:
  /pets:
    ..
  /pets/{id}:
    ..
  x-oasis-router: HelloRouter
```

### Summary

We also can set a router name when run `mix oas.gen.plug` with the `--router` argument, it applies to the router module and always override the defined from the specification file.

Follow Elixir's module naming conventions, each dot(".") of module name will split the alias as a directory in lowercase to concat the full directory path,
and also we do not validate the value of this field in a strict mode, so please follow the usual naming conventions as much as possible.

## Save Data from Bearer Token

`"x-oasis-key-to-assigns"`, optional, after the verification of the token, the original data will be stored into this provided field (as an atom) of the `conn.assigns` for the next accessing, if not defined it, there won't do any process for the verified original data, please see `Oasis.Plug.BearerAuth` for details.

### Example

Once the input token is verified, we can access the original data(decrypted from token) via `conn.assigns.user_id` in the next plug's pipeline.

```YAML
openapi: 3.1.0

components:
  securitySchemes:
    bearerAuth: # arbitrary name for the security scheme
      type: http
      scheme: bearer
      bearerFormat: JWT
      x-oasis-key-to-assigns: user_id

paths:
  /something:
    get:
      security:
        - bearerAuth: []
```
