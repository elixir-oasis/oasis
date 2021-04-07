defmodule Oasis.TokenTest do
  use ExUnit.Case

  alias Oasis.Token.Crypto

  import Oasis.Token

  test "is_key_base/1" do
    require Oasis.Token
    assert Oasis.Token.is_key_base(nil) == false
    assert Oasis.Token.is_key_base(:ok) == false
    assert Oasis.Token.is_key_base(1) == false
    assert Oasis.Token.is_key_base("1") == false

    assert Oasis.Token.is_key_base(random_string(19)) == false
    assert Oasis.Token.is_key_base(random_string(20)) == true
    assert Oasis.Token.is_key_base(random_string(21)) == true
  end

  test "sign/2 with invalid crypto" do
    assert_raise FunctionClauseError, ~r|no function clause matching in Oasis.Token.sign/2|, fn ->
      sign(%Crypto{secret_key_base: "secret_key_base"}, 123)
    end

    assert_raise FunctionClauseError, ~r|no function clause matching in Plug.Crypto.sign/4|, fn ->
      # missing `:salt`
      sign(%Crypto{secret_key_base: random_string(20)}, 123) |> IO.inspect
    end
  end

  test "sign/2 with valid crypto" do
    assert is_bitstring(sign(%Crypto{secret_key_base: random_string(20), salt: "123"}, 123)) == true
  end

  test "verify/2 with invalid crypto" do
    assert_raise FunctionClauseError, ~r|no function clause matching in Oasis.Token.verify/2|, fn ->
      verify(%Crypto{secret_key_base: "secret_key_base"}, "token")
    end

    assert_raise FunctionClauseError, ~r|no function clause matching in Plug.Crypto.verify/4|, fn ->
      verify(%Crypto{secret_key_base: random_string(20)}, "token")
    end
  end

  test "verify/2 with valid token" do
    crypto = %Crypto{secret_key_base: random_string(20), salt: "abcdef"}
    data = 123
    token = sign(crypto, data)
    assert verify(crypto, token) == {:ok, data}
  end

  test "verify/2 with expired token" do
    crypto = %Crypto{secret_key_base: random_string(20), salt: "abcdef", max_age: 1}
    data = 123
    token = sign(crypto, data)
    assert verify(%{crypto | max_age: 0}, token) == {:error, :expired}
  end

  test "verify/2 with invalid token" do
    crypto = %Crypto{secret_key_base: random_string(20), salt: "abcdef"}
    assert verify(crypto, "unknowntoken") == {:error, :invalid}
  end

  test "encrypt/2" do
    crypto = %Crypto{secret_key_base: random_string(20), secret: "abcdef"}
    assert is_bitstring(encrypt(crypto, %{"username" => "hello"})) == true
  end

  test "decrypt/2 with valid token" do
    crypto = %Crypto{secret_key_base: random_string(20), secret: "abcdef"}
    data = %{"nickname" => "hello"}
    token = encrypt(crypto, data)
    assert decrypt(crypto, token) == {:ok, data}
  end

  test "decrypt/2 with invalid token" do
    crypto = %Crypto{secret_key_base: random_string(20), secret: "abcdef"}
    data = %{"nickname" => "abc"}
    token = encrypt(crypto, data)
    assert decrypt(crypto, "#{token}.123") == {:error, :invalid}
    assert decrypt(crypto, "unknowntoken") == {:error, :invalid}
  end
end
