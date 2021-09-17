plug(
  Oasis.Plug.HmacAuth,
  signed_headers: <%= inspect(signed_headers) %>,
  scheme: <%= inspect(scheme) %>,
  security: <%= inspect(security) %>
)
