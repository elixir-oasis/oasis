plug(
  Oasis.Plug.HMACAuth,
  security: <%= inspect(security) %>,
  signed_headers: <%= inspect(signed_headers) %>,
  algorithm: <%= inspect(algorithm) %>
)
