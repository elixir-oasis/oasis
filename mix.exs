defmodule Oasis.MixProject do
  use Mix.Project

  @source_url "https://github.com/elixir-oasis/oasis"

  def project do
    [
      app: :oasis,
      version: "0.2.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      description: description(),
      package: package(),
      elixirc_paths: elixirc_paths(Mix.env()),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp description do
    "The Elixir server implementation of OpenAPI Specification v3 within Plug"
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:yaml_elixir, "~> 2.5"},
      {:plug, "~> 1.11"},
      {:jason, "~> 1.2"},
      {:ex_json_schema, "~> 0.7"},
      {:recase, "~> 0.7", runtime: false},
      {:plug_cowboy, "~> 2.0", only: [:dev, :test]},
      {:finch, "~> 0.6", only: [:dev, :test]},
      {:excoveralls, "~> 0.10", only: :test},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README.md", "LICENSE.md", "priv/templates"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url
      }
    ]
  end

  defp docs() do
    [
      main: "readme",
      source_url: @source_url,
      formatter_opts: [gfm: true],
      extras: [
        "README.md",
        "CHANGELOG.md"
      ],
      groups_for_modules: groups_for_modules()
    ]
  end

  defp groups_for_modules() do
    [
      Plugs: [
        Oasis.Plug.RequestValidator
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
