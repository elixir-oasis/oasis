plug(
  Oasis.Plug.BearerAuth,
  <%= if key_to_assigns != nil do %>key_to_assigns: <%= inspect(String.to_atom(key_to_assigns)) %>,<% end %>
  security: <%= inspect(security) %>
)
