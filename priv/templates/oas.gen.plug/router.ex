defmodule <%= inspect context.module_name %> do
  # NOTICE: This module is generated from the corresponding mix task command with the OpenAPI Specification file.
  use Oasis.Router

  plug(:match)
  plug(:dispatch)
  <%= for router <- context.routers do %>
  <%= router.http_verb %>(
    <%= inspect router.url %>,
    <%= if router.path_schema != nil do %>private: %{
      path_schema: <%= inspect router.path_schema %>
    },
    <% end %>to: <%= inspect router.pre_plug_module %>
  )
  <% end %>

  match _ do
    conn
  end
end
