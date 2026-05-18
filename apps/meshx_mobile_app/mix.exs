defmodule MeshxMobileApp.MixProject do
  use Mix.Project

  def project do
    [
      app: :meshx_mobile_app,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: false,
      deps: deps(),
      aliases: aliases(),
      erlc_paths: ["src"],
      erlc_options: [:debug_info],
      # Exclude runtime-only modules from coverage averaging — these are
      # only exercised by an actual device/UI/Erlang-startup and have no
      # meaningful unit-test surface. Without this exclusion the average
      # is dragged below 90% by ~12 modules sitting at 0%/low coverage.
      test_coverage: [
        summary: [threshold: 90],
        ignore_modules: [
          :meshx_mobile_app,
          MeshxMobileApp.App,
          MeshxMobileApp.BLE.Capture,
          MeshxMobileApp.BleSelfTest,
          MeshxMobileApp.HomeScreen,
          MeshxMobileApp.NativeBridge,
          MeshxMobileApp.NativeBridge.IOS,
          MeshxMobileApp.NativeBridge.Noop,
          Mix.Tasks.Meshx.Mobile.AdvertGossip.Audit,
          Mix.Tasks.Meshx.Mobile.Capture,
          Mix.Tasks.Meshx.Mobile.DeployDevice,
          Mix.Tasks.Meshx.Mobile.Replay,
          Mix.Tasks.Meshx.PatchDeps
        ]
      ]
    ]
  end

  # Project-local patches to vendored deps (mob_dev build template + mob
  # static NIF table) for our extra Swift sources and meshx_ble_nif. The
  # `meshx.patch_deps` task is idempotent — safe to run on every deps
  # change. See `mix help meshx.patch_deps`.
  defp aliases do
    [
      "deps.get": ["deps.get", "meshx.patch_deps"],
      "deps.update": ["deps.update", "meshx.patch_deps"],
      "deps.compile": ["meshx.patch_deps", "deps.compile"]
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
