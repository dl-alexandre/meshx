defmodule Mob.Noise.MixProject do
  use Mix.Project

  @github_url "https://github.com/dl-alexandre/meshx"

  def project do
    [
      app: :mob_noise,
      version: "0.3.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      test_coverage: [
        ignore_modules: [Mob.Noise, Mob.Noise.Supervisor],
        summary: [threshold: 90]
      ],
      deps: deps(),
      source_url: @github_url,
      homepage_url: @github_url,
      description: "Noise XX sessions and Sender Keys group encryption for MeshX mesh networking",
      package: package()
    ]
  end

  defp package do
    [
      licenses: ["Apache-2.0"],
      files: ~w(lib mix.exs README.md LICENSE),
      links: %{
        "GitHub" => @github_url,
        "Changelog" => "#{@github_url}/blob/master/CHANGELOG.md"
      }
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Mob.Noise, []}
    ]
  end

  defp deps do
    [
      {:decibel, "~> 0.2.0"}
    ]
  end
end
