defmodule H3Geo.MixProject do
  use Mix.Project

  @version "0.1.2"
  @github_url "https://github.com/breakroom/h3geo"

  def project do
    [
      app: :h3geo,
      name: "H3Geo",
      description: "H3 geospatial indexing library",
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
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
      {:rustler, "~> 0.31", optional: true},
      {:rustler_precompiled, "~> 0.7"},
      {:geo, "~> 3.6"},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:benchee, "~> 1.0", only: :dev}
    ]
  end

  defp package do
    [
      maintainers: ["Tom Taylor"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => @github_url
      },
      files: [
        "lib",
        "native/h3geo/.cargo",
        "native/h3geo/src",
        "native/h3geo/Cargo*",
        "checksum-*.exs",
        "mix.exs",
        "LICENSE"
      ]
    ]
  end

  defp docs do
    [
      main: "H3Geo",
      extras: ["README.md", "CHANGELOG.md"],
      source_ref: @version
    ]
  end
end
