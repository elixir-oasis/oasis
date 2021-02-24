defmodule Oasis.Spec.PathTest do
  use ExUnit.Case

  alias Oasis.Spec.Path

  test "format url" do
    url = "/{a}"
    assert Path.format_url(url) == "/:a"

    url = "/a/{b}/c"
    assert Path.format_url(url) == "/a/:b/c"

    url = "/a/{b}/{c}/d"
    assert Path.format_url(url) == "/a/:b/:c/d"

    url = "/a/{b}/c/{d}/{e}"
    assert Path.format_url(url) == "/a/:b/c/:d/:e"

    url = "/a/b/c"
    assert Path.format_url(url) == "/a/b/c"

    url = "/{a}/{b}/{c}"
    assert Path.format_url(url) == "/:a/:b/:c"

    url = "/a.{format}"
    assert Path.format_url(url) == "/a.:format"

    url = "/users/{.id}"
    assert Path.format_url(url) == "/users/:id"

    url = "/users/{.id*}"
    assert Path.format_url(url) == "/users/:id"

    url = "/users/{;id}"
    assert Path.format_url(url) == "/users/:id"

    url = "/users/{;id*}"
    assert Path.format_url(url) == "/users/:id"
  end
end
