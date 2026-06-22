defmodule Mob.Runtime.MixProject do
  use Mix.Project

  @github_url "https://github.com/dl-alexandre/meshx"

  def project do
    [
      app: :mob_runtime,
      version: "0.3.0",
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
      files: ~w(lib mix.exs README.md LICENSE),
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
    # (formerly :meshx_mob — that sibling was absorbed into mob_node;
    # mob_runtime cannot depend on mob_node without a cycle, so the
    # platform helpers it used live elsewhere now)
    [{:telemetry, "~> 1.0"}] ++ umbrella_deps()
  end

  # In-umbrella development resolves sibling apps by path; a published build
  # (sibling mix.exs absent) pins the corresponding Hex releases.
  defp umbrella_deps do
    if File.exists?(Path.expand("../mob_protocol/mix.exs", __DIR__)) do
      [
        {:mob_protocol, in_umbrella: true},
        {:mob_noise, in_umbrella: true},
        {:mob_store, in_umbrella: true},
        {:mob_routing, in_umbrella: true},
        {:mob_routing_ble, in_umbrella: true}
      ]
    else
      [
        {:mob_protocol, "~> 0.2"},
        {:mob_noise, "~> 0.3"},
        {:mob_store, "~> 0.3"},
        {:mob_routing, "~> 0.2"},
        {:mob_routing_ble, "~> 0.2"}
      ]
    end
  end
end
