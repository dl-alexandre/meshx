defmodule MeshxMob.MixProject do
  use Mix.Project

  def project do
    [
      app: :meshx_mob,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      test_coverage: [summary: [threshold: 90]],
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      # No direct deps — relies on umbrella apps
    ]
  end
end
