plug(
  Oasis.Plug.HMACAuth,
  signed_headers: <%= inspect(signed_headers) %>,
  scheme: <%= inspect(scheme) %>,
  security: <%= inspect(security) %>
)
