defmodule Meshx.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "0.1.0",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      dialyzer: dialyzer()
    ]
  end

  # Dependencies listed here are available only for this
  # project and cannot be accessed from applications inside
  # the apps folder.
  defp deps do
    [
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:styler, "~> 1.5", only: [:dev, :test], runtime: false}
    ]
  end

  defp docs do
    [
      main: "Meshx",
      extras: [
        "README.md",
        "docs/CONTRACTS.md",
        "docs/ARCHITECTURE.md",
        "docs/RUNTIME_API.md",
        "docs/TRANSPORTS.md",
        "docs/BLE_BRIDGE.md",
        "docs/OPERATIONS.md",
        "docs/DEPLOYMENT.md",
        "docs/METRICS.md",
        "docs/KEY_ROTATION.md",
        "docs/FAILURE_RECOVERY.md"
      ]
    ]
  end

  defp dialyzer do
    [
      plt_local_path: "_build/plts",
      plt_core_path: "_build/plts",
      plt_add_apps: [:mix, :ex_unit],
      flags: [:error_handling, :unknown, :unmatched_returns],
      paths: umbrella_ebin_paths(),
      ignore_warnings: ".dialyzer_ignore.exs"
    ]
  end

  defp umbrella_ebin_paths do
    apps = ~w(meshx_protocol meshx_noise meshx_store meshx_transport
              meshx_transport_ble meshx_mob meshx_runtime)

    Enum.map(apps, fn app -> "_build/#{Mix.env()}/lib/#{app}/ebin" end)
  end
end
