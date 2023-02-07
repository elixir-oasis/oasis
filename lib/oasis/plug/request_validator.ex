defmodule Oasis.Plug.RequestValidator do
  @moduledoc ~S"""
  A plug to convert types and validate the HTTP request parameters by the schemas of
  the OpenAPI definition.

  The schema options can be found in the generated `pre-` plug handler file, the full list:

    * `:query_schema`
    * `:header_schema`
    * `:cookie_schema`
    * `:body_schema`

  All of these options are fully map and generated from the corresponding definition of the OpenAPI Specification.

  When the query parameters are verified by the validation of `:query_schema`, the coverted types of query parameters
  are reserved in `:query_params` and `:params` field of the `Plug.Conn`.

  When the header parameters are verified by the validation of `:header_schema`, the converted types of header parameters
  are reserved in `:req_headers` field of the `Plug.Conn`.

  When the cookie parameters are verified by the validation of `:cookie_schema`, the coverted types of cookie parameters
  are reserved in `:req_cookies` field of the `Plug.Conn`.

  When the request body is verified by the validation of `:body_schema`, the coverted types of request body are reserved
  in `:body_params` and `:params` field of the `Plug.Conn`.
  """

  import Plug.Conn

  @behaviour Plug

  require Logger

  def init(opts), do: opts

  def call(conn, opts) do
    conn
    |> process_query(opts[:query_schema])
    |> process_header(opts[:header_schema])
    |> process_cookie(opts[:cookie_schema])
    |> process_body(opts[:body_schema])
  end

  defp process_query(conn, query_schema) when is_map(query_schema) do
    conn = fetch_query_params(conn)

    %{query_params: query_params, path_params: path_params, params: params} = conn

    query_params = parse_and_validate(query_schema, query_params, "query")

    params = params |> Map.merge(query_params) |> Map.merge(path_params)

    %{conn | query_params: query_params, params: params}
  end

  defp process_query(conn, _) do
    conn
  end

  defp process_header(conn, header_schema) when is_map(header_schema) do
    header_params = parse_and_validate(header_schema, Map.new(conn.req_headers), "header")

    %{conn | req_headers: Map.to_list(header_params)}
  end

  defp process_header(conn, _) do
    conn
  end

  defp process_cookie(conn, cookie_schema) when is_map(cookie_schema) do
    conn = fetch_cookies(conn)

    cookie_params = parse_and_validate(cookie_schema, conn.req_cookies, "cookie")

    %{conn | req_cookies: cookie_params}
  end

  defp process_cookie(conn, _) do
    conn
  end

  defp process_body(%{body_params: %Plug.Conn.Unfetched{}} = conn, _) do
    # By default, we use `Plug` built-in parsers to process request body before
    # this function, if these built-in parsers do not match the request, we will
    # ignore the request to be formatted and validated.
    conn
  end

  defp process_body(
         %{body_params: %{"_json" => _body_params}, params: params} = conn,
         body_schema
       )
       when is_map(body_schema) do

    body_params = parse_and_validate_body_params(conn, body_schema)

    if is_map(body_params) do
      # Maybe the defined schema specification use the "_json" key as a property of an object.
      params = Map.merge(params, body_params)
      %{conn | body_params: body_params, params: params}
    else
      %{conn | body_params: body_params, params: body_params}
    end
  end

  defp process_body(
         %{params: params} = conn,
         body_schema
       )
       when is_map(body_schema) do

    body_params = parse_and_validate_body_params(conn, body_schema)

    params = Map.merge(params, body_params)

    %{conn | body_params: body_params, params: params}
  end

  defp process_body(conn, _) do
    conn
  end

  defp parse_and_validate_body_params(%{body_params: body_params, req_headers: req_headers}, body_schema) do
    req_headers
    |> find_content_type()
    |> schema_may_match_by_request(body_schema)
    |> Oasis.Validator.parse_and_validate!("body", "body_request", body_params)
  end

  defp parse_and_validate(schemas, input_params, use_in) when is_map(input_params) do
    Enum.reduce(schemas, input_params, fn {param_name, definition}, acc ->
      input_value = input_params[param_name]

      prepared_value =
        Oasis.Validator.parse_and_validate!(definition, use_in, param_name, input_value)

      if prepared_value == nil and input_value == nil do
        acc
      else
        Map.put(acc, param_name, prepared_value)
      end
    end)
  end

  defp find_content_type(req_headers) do
    case List.keyfind(req_headers, "content-type", 0) do
      {_, content} ->
        String.downcase(content)
      nil ->
        nil
    end
  end

  defp schema_may_match_by_request("multipart/mixed" <> _, definition) do
    schema_by_request_content_type("multipart/mixed", definition)
  end

  defp schema_may_match_by_request("multipart/form-data" <> _, definition) do
    schema_by_request_content_type("multipart/form-data", definition)
  end

  defp schema_may_match_by_request("text/plain" <> _charset, definition) do
    schema_by_request_content_type("text/plain", definition)
  end

  defp schema_may_match_by_request("application/json" <> _charset, definition) do
    schema_by_request_content_type("application/json", definition)
  end

  defp schema_may_match_by_request("application/x-www-form-urlencoded" <> _charset, definition) do
    schema_by_request_content_type("application/x-www-form-urlencoded", definition)
  end

  defp schema_may_match_by_request(content_type, definition) do
    schema_by_request_content_type(content_type, definition)
  end

  defp schema_by_request_content_type(content_type, %{"content" => content} = definition) do
    matched = Map.take(content, [content_type])

    if matched != %{} do
      %{definition | "content" => matched}
    else
      nil
    end
  end

  defp schema_by_request_content_type(_content_type, _definition) do
    nil
  end
end
