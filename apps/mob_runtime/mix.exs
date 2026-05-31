defmodule Mob.Runtime.MixProject do
  use Mix.Project

  @github_url "https://github.com/dl-alexandre/meshx"

  def project do
    [
      app: :mob_runtime,
      version: "0.2.0",
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
      mod: {Mob.Runtime, []},
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:mob_protocol, in_umbrella: true},
      {:mob_noise, in_umbrella: true},
      {:mob_store, in_umbrella: true},
      {:mob_routing, in_umbrella: true},
      {:mob_routing_ble, in_umbrella: true},
      # (formerly :meshx_mob — that sibling was absorbed into mob_node;
      # mob_runtime cannot depend on mob_node without a cycle, so the
      # platform helpers it used live elsewhere now)
      {:telemetry, "~> 1.0"}
    ]
  end
end
