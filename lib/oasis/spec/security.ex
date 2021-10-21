defmodule Oasis.Spec.Security do
  @moduledoc false

  def build(%{"security" => security_requirement_objects}, security_schemes)
      when is_map(security_schemes) and security_schemes != %{} 
        and is_list(security_requirement_objects) do
    # Use in process the security globally to all operations,
    # or use in process the security to an operation.
    prepare_security_schemes(security_requirement_objects, security_schemes)
  end
  def build(_, _), do: nil

  def security_schemes(%{"components" => %{"securitySchemes" => security_schemes}})
    when is_map(security_schemes) do
    security_schemes
  end
  def security_schemes(_), do: nil

  defp prepare_security_schemes(security_requirement_objects, security_schemes) do
    prepared =
      Enum.reduce(security_requirement_objects, [], fn(security_requirement_object, acc) ->
        [{security_name, _scopes}] = Map.to_list(security_requirement_object)

        security_definition = Map.get(security_schemes, security_name)

        if supported_security?(security_definition) do
          acc ++ [{security_name, security_definition}]
        else
          acc
        end
      end)
    if prepared == [], do: nil, else: prepared
  end

  defp supported_security?(%{"type" => "http", "scheme" => "bearer"}), do: true
  defp supported_security?(_), do: false

end
