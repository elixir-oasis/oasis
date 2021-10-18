plug(
  Oasis.Plug.HMACAuth,
  signed_headers: <%= inspect(signed_headers) %>,
  algorithm: <%= inspect(algorithm) %>,
  security: <%= inspect(security) %>
)
