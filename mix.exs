defmodule Stl.MixProject do
  use Mix.Project

  @version "0.1.0"
  @description "Seasonal-trend decomposition for Elixir using STL"
  @github_url "https://github.com/supermethodhq/ex_stl"

  def project do
    [
      app: :stl,
      version: @version,
      elixir: "~> 1.16",
      compilers: [:elixir_make] ++ Mix.compilers(),
      make_env: fn -> %{"FINE_INCLUDE_DIR" => Fine.include_dir()} end,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: @description,
      package: package(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:fine, "~> 0.1", runtime: false},
      {:elixir_make, "~> 0.9", runtime: false},
      {:ex_doc, "~> 0.37", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      main: "STL",
      source_url: @github_url,
      source_ref: "v#{@version}"
    ]
  end

  defp package do
    [
      files: [
        "lib",
        "c_src",
        "mix.exs",
        "Makefile",
        "README.md",
        "LICENSE",
        "CHANGELOG.md"
      ],
      maintainers: ["Supermethod"],
      licenses: ["MIT"],
      links: %{"GitHub" => @github_url}
    ]
  end
end
