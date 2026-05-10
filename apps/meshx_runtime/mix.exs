defmodule MeshxRuntime.MixProject do
  use Mix.Project

  def project do
    [
      app: :meshx_runtime,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      test_coverage: [summary: [threshold: 90]],
      deps: deps()
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
