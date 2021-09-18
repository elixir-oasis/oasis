defmodule Oasis.Test.Support.Hmac do
  def case_host_only() do
    %{
      credential: "test_client",
      secret: "secret",
      path_and_query: "/test?a=b",
      host: "localhost:4000",
      signed_headers: "host",
      signature_sha256: "aqg8DKRSwWhFQq9lr/TwTL//3F3p72bBpDSIfjqYoms=",
      signature_sha512:
        "NNf3rbPKndxcBuqIM3vDm8lW2lGHAyQUxZN6C1Ym9EdfHerIB5Iv/q5rtK61uYlzxWesEv+yMAvKnZxkbXqP2g==",
      signature_md5: "VuugLKUj0LT62ZwJfrHK8Q=="
    }
  end

  def case_with_date() do
    %{
      credential: "test_client",
      secret: "secret",
      path_and_query: "/test?a=b",
      host: "localhost:4000",
      x_oasis_date: "Wed, 15 Sep 2021 06:41:35 GMT",
      signed_headers: "host;x-oasis-date",
      signature_sha256: "1xRhjH97JJ2r/17XlIxtGv1N4XNf5t8Qu8UN94xmlpM="
    }
  end
end

defmodule Oasis.Test.Support.Hmac.TokenHostOnly do
  @behaviour Oasis.HmacToken

  alias Oasis.HmacToken.Crypto
  import Oasis.Test.Support.Hmac

  @impl true
  def crypto_configs(_conn, _opts) do
    c = case_host_only()

    [
      %Crypto{
        credential: c.credential,
        secret: c.secret
      }
    ]
  end
end

defmodule Oasis.Test.Support.Hmac.TokenWithDate do
  @behaviour Oasis.HmacToken

  alias Oasis.HmacToken.Crypto
  import Oasis.Test.Support.Hmac

  @impl true
  def crypto_configs(_conn, _opts) do
    c = case_host_only()

    [
      %Crypto{
        credential: c.credential,
        secret: c.secret
      }
    ]
  end

  @impl true
  def verify(conn, token, opts) do
    with {:ok, _} <- Oasis.HmacToken.verify(conn, token, opts) do
      # actual:
      # parse & verify date
      # could not before (now - max_age)
      {:error, :expired}
    end
  end
end
