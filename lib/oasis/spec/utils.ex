defmodule Oasis.Spec.Utils do
  @moduledoc false

  alias Oasis.InvalidSpecError

  @type json_schema_root :: ExJsonSchema.Schema.Root.t()

  @doc """
  Expand and place all `$ref` properties with the corresponding fragments.
  """
  @spec expand_ref(json_schema_root) :: json_schema_root
  def expand_ref(root) do
    schema = expand_into_ref(root, root.schema)
    %{root | schema: schema}
  end

  defp expand_into_ref(root, object) when is_map(object) do
    Enum.reduce(object, %{}, fn
      {key, value}, acc when key == "$ref" ->
        value = map_ref(root, key, value)

        Map.merge(acc, value)

      {key, value}, acc ->
        if Map.has_key?(acc, key) do
          raise InvalidSpecError,
                "Defined a duplicated field: `#{key}` key as:\n#{
                  inspect(%{key => value}, pretty: true)
                } \n to \n#{inspect(acc, pretty: true)}"
        else
          value = map_ref(root, key, value)
          Map.put(acc, key, value)
        end
    end)
  end

  defp expand_into_ref(_root, object) do
    object
  end

  defp map_ref(root, "$ref", value) do
    fragment = ExJsonSchema.Schema.get_fragment!(root, value)
    expand_into_ref(root, fragment)
  end

  defp map_ref(root, _key, value) when is_list(value) do
    Enum.map(value, fn item ->
      expand_into_ref(root, item)
    end)
  end

  defp map_ref(root, _key, value) when is_map(value) do
    expand_into_ref(root, value)
  end

  defp map_ref(_root, _key, value) do
    value
  end
end
