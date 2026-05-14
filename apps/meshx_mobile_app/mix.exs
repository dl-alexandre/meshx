defmodule MeshxMobileApp.MixProject do
  use Mix.Project

  def project do
    [
      app: :meshx_mobile_app,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: false,
      deps: deps(),
      erlc_paths: ["src"],
      erlc_options: [:debug_info]
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:meshx_runtime, in_umbrella: true},
      {:meshx_mob, in_umbrella: true},
      {:meshx_store, in_umbrella: true},
      {:mob, "~> 0.5"},
      {:mob_dev, "~> 0.3", only: [:dev, :test], runtime: false}
    ]
  end
end
