defmodule MeshxNoise.MixProject do
  use Mix.Project

  @github_url "https://github.com/dl-alexandre/meshx"

  def project do
    [
      app: :meshx_noise,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      test_coverage: [
        ignore_modules: [MeshxNoise, MeshxNoise.Supervisor],
        summary: [threshold: 90]
      ],
      deps: deps(),
      source_url: @github_url,
      homepage_url: @github_url,
      description: "Noise XX session wrapper for MeshX mesh networking over Decibel",
      package: package()
    ]
  end

  defp package do
    [
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => @github_url,
        "Changelog" => "#{@github_url}/blob/master/CHANGELOG.md"
      }
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:decibel, "~> 0.2.0"}
    ]
  end
end
