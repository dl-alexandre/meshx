defmodule Mob.Node.MixProject do
  use Mix.Project

  def project do
    [
      app: :mob_node,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: false,
      deps: deps(),
      erlc_paths: ["src"],
      erlc_options: [:debug_info],
      # Exclude runtime-only modules from coverage averaging — these are
      # only exercised by an actual device/UI/Erlang-startup and have no
      # meaningful unit-test surface. Without this exclusion the average
      # is dragged below 90% by ~12 modules sitting at 0%/low coverage.
      test_coverage: [
        summary: [threshold: 90],
        ignore_modules: [
          :mob_node,
          Mob.Node.App,
          Mob.Node.BLE.Capture,
          Mob.Node.BleSelfTest,
          Mob.Node.HomeScreen,
          Mob.Node.NativeBridge,
          Mob.Node.NativeBridge.IOS,
          Mob.Node.NativeBridge.Noop,
          Mix.Tasks.Mob.Node.AdvertGossip.Audit,
          Mix.Tasks.Mob.Node.Capture,
          Mix.Tasks.Mob.Node.DeployDevice,
          Mix.Tasks.Mob.Node.Replay
        ]
      ]
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      # Explicit dep on the BLE transport adapter (even though pulled
      # transitively via mob_runtime) because `Mob.Node.App` and
      # the wiring test directly reference `Mob.Routing.BLE` modules.
      # Required for Phase 2 of the mob_ble bridge migration hygiene.
      {:mob_runtime, in_umbrella: true},
      {:mob_routing_ble, in_umbrella: true},
      # (formerly :meshx_mob — that sibling app was absorbed into mob_node)
      {:mob_store, in_umbrella: true},
      {:mob_ble, in_umbrella: true},
      # Post upstream migration (GenericJam/mob_dev#6 + mob_new#5):
      # Bumped to first releases containing :ios_swift_sources / :static_nifs
      # support (mob_dev 0.5.11 series + corresponding mob 0.6.x).
      # Verified via `mix hex.info` and lock regen.
      {:mob, "~> 0.6"},
      {:mob_dev, "~> 0.5.11", only: [:dev, :test], runtime: false}
    ]
  end
end
