# HMAC-based Authentication

## Scenario

Sometimes our services need to allow other specific backend applications to access.

Then we need a mechanism based on `HTTP Authorization Header` to authenticate access permissions to meet the following requirements:

1. Make sure that the request is from a trusted client.
2. Make sure that the `HTTP Header` has not been tampered with.
3. *(Optional)* Make sure that the `HTTP Body` has not been tampered with.
4. *(Optional)* Make sure that the interval between request start-time and the current time does not exceed a certain critical value.

Oasis provides a complete set of scaffolding to easily build such a set of certification services.

## Protocol

### Notice

Requests must be transmitted over `TLS`.

### Reference

Here are some related implementation by other services:

* https://docs.microsoft.com/en-us/azure/azure-app-configuration/rest-api-authentication-hmac
* https://docs.aws.amazon.com/AmazonS3/latest/API/sigv4-auth-using-authorization-header.html
* https://docs.aws.amazon.com/general/latest/gr/sigv4-signed-request-examples.html

### HTTP Authorization Header

The client request must contains header:

`Authorization: HMAC-uppercase(<algorithm>) Credential=<value>&SignedHeaders=<value>&Signature=<value>`

* `Algorithm`
    * Some digest/hash algorithm, see [Algorithms Supported](Oasis.Plug.HMACAuth.html#module-algorithms-supported) for details.
* `Credential`
    * ID of the access key used to signature and verify, must be defined in `Oasis.HMACToken.Crypto`.
* `SignedHeaders`
    * HTTP request header names, separated by semicolons, required to sign the request in your defined order of `x-oasis-signed-headers` spec, the HTTP headers must be correctly provided with the request as well, do not use white spaces.
* `Signature`
    * Base64 encoded HMAC-<algorithm> hash of the String-To-Sign, it uses the value(aka Secret) of the access key identified by Credential
    * pseudo code as below:
        * `base64_encode(hmac-<algorithm>(String-To-Sign, Secret))`
* `String-To-Sign`
    * `String-To-Sign` = `HTTP_METHOD` + `'\n'` + `path_and_query` + `'\n'` + `signed_headers_values`
    * `HTTP_METHOD`, uppercase HTTP method name used with the request.
    * `path_and_query`, concatenation of request absolute URI and query string.
    * `signed_headers_values`, semicolon-separated values of all HTTP request headers listed in `SignedHeaders`.

### Example
Assume we define `x-oasis-signed-headers: x-oasis-date;host` as a part of the security scheme, the following HTTP headers in request:

  ```text
  x-oasis-date: Mon, 13 Sep 2021 03:21:00 GMT
  Host: www.foo.bar
  ```

In this case, the concatenated String-To-Sign as below:

  ```text
  String-To-Sign =
  "GET" + "\n"
  "/post?a=1&b=2" + "\n"
  "Mon, 13 Sep 2021 03:21:00 GMT;www.foo.bar"
  ```

Reference the best practices, the above example missing the key important variable Body of HTTP request, it should be used into the signature even if there is no body.

Since the way to concatenate String-To-Sign is a fixed step, we can customize a new HTTP header field to represent the Body into the SignedHeaders, and keep the value of the new field in the request for the service side verification, for example:

  ```text
  x-oasis-content-sha256: base64_encode(SHA256(body))
  x-oasis-content-md5: base64_encode(MD5(body))
  ```

## Tutorial

### 1. Define schema in OpenAPI Specification

```yaml
# priv/oas/main.yaml

openapi: "3.0.0"
info:
  title: My API Title
  version: "1.0"
paths:
  /test_hmac:
    post:
      # this API (/test_hmac) should be authenticated by HMAC-based Authentication
      security:
        - HMACAuth: [ ]
      requestBody:
        content:
          application/json:
            schema:
              type: object
              properties:
                a:
                  type: string
      responses:
        "200":
          description: OK
  /other:
    get:
      # and this API will not be authenticated 
      responses:
        "200":
          description: OK
    
components:
  securitySchemes:
    HMACAuth:
      type: http
      # will use sha256 as digest algorithm
      scheme: hmac-sha256
      # will verify host, request datetime and body hash
      x-oasis-signed-headers: host;x-oasis-date;x-oasis-body-sha256
```


### 2. Generate Code

```shell
# in the shell
mix oas.gen.plug --file priv/oas/main.yaml
```

Then you will get several generated files:

```elixir
# lib/oasis/gen/pre_post_test_hmac.ex

defmodule Oasis.Gen.PrePostTestHMAC do
  # NOTICE: Please DO NOT write any business code in this module, since it will always be overridden when
  # run `mix oas.gen.plug` task command with the OpenAPI Specification file.
  use Oasis.Controller
  use Plug.ErrorHandler

  plug(
    Plug.Parsers,
    parsers: [:json],
    json_decoder: Jason,
    pass: ["*/*"],
    body_reader: {Oasis.CacheRawBodyReader, :read_body, []}
  )

  plug(
    Oasis.Plug.RequestValidator,
    body_schema: %{
      "content" => %{
        "application/json" => %{
          "schema" => %ExJsonSchema.Schema.Root{
            schema: %{"properties" => %{"a" => %{"type" => "string"}}, "type" => "object"}
          }
        }
      }
    }
  )

  plug(
    Oasis.Plug.HMACAuth,
    signed_headers: "host;x-oasis-date;x-oasis-body-sha256",
    algorithm: :sha256,
    security: Oasis.Gen.HMACAuth
  )

  def call(conn, opts) do
    conn |> super(opts) |> Oasis.Gen.PostTestHMACWithBody.call(opts) |> halt()
  end

  defdelegate handle_errors(conn, error), to: Oasis.Gen.PostTestHMACWithBody
end
```

```elixir
# lib/oasis/gen/hmac_auth.ex

defmodule Oasis.Gen.HMACAuth do
  # NOTICE: This module is generated when run `mix oas.gen.plug` task command with the OpenAPI Specification file
  # in the first time, and then it WILL NOT be modified in the future generation command(s) once this file exists,
  # please write the crypto-related configuration to the bearer token in this module.
  @behaviour Oasis.HMACToken
  alias Oasis.HMACToken.Crypto

  @impl true
  def crypto_config(_conn, _opts, _credential) do
    # ...
    nil
  end

  @impl true
  def verify(conn, token, opts) do
    with {:ok, _} <- Oasis.HMACToken.verify(conn, token, opts) do
      {:ok, token}
    end
  end
end
```

### 3. Provide your own `crypto_config/3` and `verify/3` logics

* Example:

```elixir
# lib/oasis/gen/hmac_auth.ex

defmodule Oasis.Gen.HMACAuth do
  
  # NOTICE: This module is generated when run `mix oas.gen.plug` task command with the OpenAPI Specification file
  # in the first time, and then it WILL NOT be modified in the future generation command(s) once this file exists,
  # please write the crypto-related configuration to the bearer token in this module.
  @behaviour Oasis.HMACToken
  alias Oasis.HMACToken.Crypto
  
  # in seconds
  @max_diff 60

  @impl true
  def crypto_config(_conn, _opts, _credential) do
    # Here just an example
    # You should provide these sensitive information from config file or database
    %Crypto{
      credential: "test_client",
      secret: "secret"
    }
  end

  @impl true
  def verify(conn, token, opts) do
    with {:ok, _} <- Oasis.HMACToken.verify(conn, token, opts),
         {:ok, _} <- verify_date(conn, token, opts),
         {:ok, _} <- verify_body(conn, token, opts) do
      {:ok, token}
  end
  
  defp verify_date(conn, token, _opts) do
    with {:ok, timestamp} <- conn |> get_header("x-oasis-date") |> parse_header_date() do
      timestamp_now = DateTime.utc_now() |> DateTime.to_unix()

      if abs(timestamp_now - timestamp) < @max_diff do
        {:ok, timestamp}
      else
        {:error, :expired}
      end
    end
  end
  
  defp verify_body(conn, token, opts) do
    algorithm = opts[:algorithm]
    raw_body = conn.assigns.raw_body
    crypto = crypto_config(conn, opts, token.credential)
    body_hmac = hmac(algorithm, crypto.secret, raw_body)
    body_hmac_header = get_header(conn, "x-oasis-body-sha256")

    if body_hmac == body_hmac_header do
      {:ok, token}
    else
      {:error, :invalid_token}
    end
  end

  defp get_header(conn, key) do
    conn
    |> Plug.Conn.get_req_header(key)
    |> case do
      [value] -> value
      _ -> nil
    end
  end
  
  defp parse_header_date(str) when is_binary(str) do
    with {:ok, datetime} <- Timex.parse(str, "%a, %d %b %Y %H:%M:%S GMT", :strftime),
         timestamp when is_integer(timestamp) <- Timex.to_unix(datetime) do
      {:ok, timestamp}
    end
  end

  defp parse_header_date(_otherwise), do: {:error, :expired}

  defp hmac(subtype, secret, content) do
    Base.encode64(:crypto.mac(:hmac, subtype, secret, content))
  end
  
end
```
