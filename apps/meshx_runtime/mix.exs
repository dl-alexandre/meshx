defmodule MeshxRuntime.MixProject do
  use Mix.Project

  @github_url "https://github.com/dl-alexandre/meshx"

  def project do
    [
      app: :meshx_runtime,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      test_coverage: [summary: [threshold: 90]],
      deps: deps(),
      source_url: @github_url,
      homepage_url: @github_url,
      description: "Top-level OTP application and runtime coordinator for MeshX mesh networking",
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
      mod: {MeshxRuntime, []},
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:meshx_protocol, in_umbrella: true},
      {:meshx_noise, in_umbrella: true},
      {:meshx_store, in_umbrella: true},
      {:meshx_transport, in_umbrella: true},
      {:meshx_transport_ble, in_umbrella: true},
      {:meshx_mob, in_umbrella: true},
      {:telemetry, "~> 1.0"}
    ]
  end
end
