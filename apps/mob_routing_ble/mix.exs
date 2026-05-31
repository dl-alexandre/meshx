defmodule Mob.Routing.BLE.MixProject do
  use Mix.Project

  @github_url "https://github.com/dl-alexandre/meshx"

  def project do
    [
      app: :mob_routing_ble,
      version: "0.2.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      test_coverage: [summary: [threshold: 90]],
      deps: deps(),
      source_url: @github_url,
      homepage_url: @github_url,
      description: "Bluetooth Low Energy (BLE) native bridge adapter for MeshX mesh networking",
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
      {:mob_routing, in_umbrella: true}
    ]
  end
end
