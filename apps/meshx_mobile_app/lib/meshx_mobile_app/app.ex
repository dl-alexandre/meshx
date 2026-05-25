defmodule MeshxMobileApp.App do
  @moduledoc """
  Mob application entry point for the MeshX mobile app.

  The app shell is Mob-first: UI and session state live in Elixir on the
  device, while platform BLE is provided by a native bridge behind
  `MeshxMobileApp.NativeBridge` (legacy) or the recommended `mob_ble`
  plugin path.

  ## Recommended production BLE path (Phase 2 default)
  The `mob_ble` transport wiring (via `Mob.Ble.Bridge` / `Mob.Ble.MobileBridge`
  + `MeshxTransportBLE`) is now the default. It is enabled unless
  `MOB_BLE_TRANSPORT=0` is set (for legacy transition). See
  `maybe_start_mob_ble_transport/0`, `Mob.Ble.bridge_module/0`, and
  `docs/mob_ble_bridge_migration.md`.

  The legacy `NativeBridge` flow remains available for backward compatibility
  during the cutover window.
  """

  use Mob.App

  require Logger

  @impl Mob.App
  def navigation(_platform) do
    stack(:meshx, root: MeshxMobileApp.HomeScreen, title: "MeshX")
  end

  @impl Mob.App
  def on_start do
    configure_native_bridge()
    start_ble_observability()
    rt_probe(:app, :mob_app_start, %{platform: safe_platform()})
    start_meshx_runtime()
    maybe_start_distribution()
    maybe_start_ble_self_test()
    maybe_start_mob_ble_transport()
    maybe_start_mob_ble_self_test()
    Mob.Screen.start_root(MeshxMobileApp.HomeScreen)
  end

  # Wiring of the recommended `mob_ble` plugin into the runtime BLE transport
  # (via the canonical `Mob.Ble.Bridge` behaviour).
  #
  # Default: ON (strongly recommended production path post-Phase 2).
  # The `mob_ble` path starts `MeshxTransportBLE` with `Mob.Ble.bridge_module()`
  # (i.e. `Mob.Ble.MobileBridge`). This routes native events (decoded via
  # `Mob.Ble.Internal.BridgeProtocol`) as canonical `{:meshx_transport, :ble, _}`
  # tuples into the MeshX runtime.
  #
  # NIF ownership: `MobileBridge` registers as the `:mob_ble_nif` callback owner.
  # Only one owner may be active; the legacy NativeBridge self-test/dispatch
  # paths must not contend for the same NIF when this path is active.
  #
  # Opt-out (legacy transition): set `MOB_BLE_TRANSPORT=0` to skip this and
  # fall back to pre-migration NativeBridge wiring.
  #
  # See: `Mob.Ble.bridge_module/0`, `docs/mob_ble_bridge_migration.md`,
  # `apps/mob_ble/lib/mob/ble/mobile_bridge.ex`, wiring test.
  defp maybe_start_mob_ble_transport do
    if System.get_env("MOB_BLE_TRANSPORT") == "0" do
      Logger.info(
        "meshx_mobile_app: mob_ble transport skipped (MOB_BLE_TRANSPORT=0; legacy path active)"
      )

      rt_probe(:transport, :mob_ble_transport_skipped, %{reason: "MOB_BLE_TRANSPORT=0"})
      :ok
    else
      local_name = System.get_env("MOB_BLE_LOCAL_NAME") || "meshx-mobile"
      rt_probe(:transport, :mob_ble_transport_start_requested, %{local_name: local_name})

      case MeshxTransportBLE.start_link(
             bridge: Mob.Ble.bridge_module(),
             bridge_opts: [local_name: local_name]
           ) do
        {:ok, _pid} ->
          Logger.info(
            "meshx_mobile_app: mob_ble transport up (bridge=#{inspect(Mob.Ble.bridge_module())})"
          )

          rt_probe(:transport, :mob_ble_transport_started, %{
            bridge: inspect(Mob.Ble.bridge_module()),
            local_name: local_name
          })

        other ->
          Logger.warning("meshx_mobile_app: mob_ble transport not started: #{inspect(other)}")
          rt_probe(:transport, :mob_ble_transport_start_failed, %{reason: inspect(other)})
      end
    end
  end

  # Best-effort in-process BLE observability surface. Started before any
  # event consumer so `Observability.record/2` calls from BleSelfTest /
  # Session are never dropped. Failures here never abort startup —
  # observability is an instrument, not a hard dependency.
  defp start_ble_observability do
    case MeshxMobileApp.BLE.Observability.start_link([]) do
      {:ok, _pid} ->
        Logger.info("meshx_mobile_app: BLE.Observability started")
        rt_probe(:app, :observability_started, %{})

      {:error, {:already_started, _pid}} ->
        rt_probe(:app, :observability_already_started, %{})
        :ok

      other ->
        Logger.warning("meshx_mobile_app: BLE.Observability not started: #{inspect(other)}")
    end
  end

  # Headless BLE bring-up probe (legacy path) — only when MESHX_BLE_SELFTEST is set
  # (Android launcher derives it from the `meshx_ble_selftest` intent
  # extra). Drives the real mob_ble_nif scan+advertise path so two
  # devices can be checked for mutual discovery from `adb logcat`.
  #
  # When the default `mob_ble` transport is active, prefer `MOB_BLE_SELFTEST=1`
  # + `Mob.Ble.SelfTest` (see `maybe_start_mob_ble_self_test/0`) to avoid
  # NIF owner contention.
  defp maybe_start_ble_self_test do
    if System.get_env("MESHX_BLE_SELFTEST") in [nil, ""] do
      :ok
    else
      # When the new mob_ble path is the default (MOB_BLE_TRANSPORT != "0"),
      # start the legacy heavy selftest in passive mode. This activates the
      # native?: false guard, avoids NIF contention with MobileBridge, and
      # lets the tuple handlers receive events if the selftest is later wired
      # as an extra event_target. The lean Mob.Ble.SelfTest remains preferred
      # for routine mob-default validation.
      mob_default = System.get_env("MOB_BLE_TRANSPORT") != "0"
      opts = if mob_default, do: [native?: false], else: []

      case MeshxMobileApp.BleSelfTest.start_link(opts) do
        {:ok, _pid} ->
          Logger.info("meshx_mobile_app: BLE self-test started (native?=#{not mob_default})")
          rt_probe(:selftest, :legacy_ble_selftest_started, %{native?: not mob_default})

        other ->
          Logger.warning("meshx_mobile_app: BLE self-test not started: #{inspect(other)}")
          rt_probe(:selftest, :legacy_ble_selftest_start_failed, %{reason: inspect(other)})
      end
    end
  end

  # Headless on-device BLE bring-up probe for the *recommended* `mob_ble`
  # path. Started when `MOB_BLE_SELFTEST=1` (or `MOB_BLE_SELFTEST` truthy).
  #
  # Uses `Mob.Ble.SelfTest` (the plugin-owned probe) which registers
  # directly with `:mob_ble_nif` via `Mob.Ble.MobileBridge` semantics and
  # logs under `MobBleSelfTest`. This is the companion to the transport
  # wiring and is the primary self-test when `mob_ble` is the active path
  # (the default).
  #
  # See `apps/mob_ble/lib/mob/ble/self_test.ex` and its moduledoc for the
  # exact contract and when to use vs. the legacy `MESHX_BLE_SELFTEST` probe.
  defp maybe_start_mob_ble_self_test do
    if System.get_env("MOB_BLE_SELFTEST") in [nil, ""] do
      :ok
    else
      case Mob.Ble.SelfTest.start_link([]) do
        {:ok, _pid} ->
          Logger.info("meshx_mobile_app: Mob.Ble.SelfTest started (mob_ble path)")
          rt_probe(:selftest, :mob_ble_selftest_started, %{})

        other ->
          Logger.warning("meshx_mobile_app: Mob.Ble.SelfTest not started: #{inspect(other)}")
          rt_probe(:selftest, :mob_ble_selftest_start_failed, %{reason: inspect(other)})
      end
    end
  end

  # Erlang distribution for on-device introspection during bring-up
  # (`mix mob.connect`). The node name is derived from the device
  # serial by the deployer via the `mob_node_suffix` intent extra, so
  # multiple devices on the same EPMD don't collide. Best-effort —
  # the mesh itself runs over BLE, not distribution.
  defp maybe_start_distribution do
    suffix = System.get_env("MOB_NODE_SUFFIX") || "dev"
    node = :"meshx_mobile_app_android_#{suffix}@127.0.0.1"

    case Mob.Dist.ensure_started(node: node, cookie: :meshx_mob_secret) do
      :ok ->
        Logger.info("meshx_mobile_app: distribution up as #{node}")
        rt_probe(:app, :distribution_started, %{node: inspect(node)})

      other ->
        Logger.warning("meshx_mobile_app: distribution not started: #{inspect(other)}")
        rt_probe(:app, :distribution_start_failed, %{reason: inspect(other)})
    end
  rescue
    error ->
      Logger.warning("meshx_mobile_app: distribution error: #{inspect(error)}")
      rt_probe(:app, :distribution_start_exception, %{error: inspect(error)})
  end

  defp configure_native_bridge do
    case :mob_nif.platform() do
      :ios ->
        if ble_nif_available?(:meshx_ble_nif) do
          Application.put_env(:meshx_mobile_app, :native_bridge, MeshxMobileApp.NativeBridge.IOS)
        end

      :android ->
        if ble_nif_available?(:mob_ble_nif) do
          Application.put_env(
            :meshx_mobile_app,
            :native_bridge,
            MeshxMobileApp.NativeBridge.Android
          )
        end

      _platform ->
        :ok
    end
  end

  defp ble_nif_available?(module) do
    match?({:module, ^module}, Code.ensure_loaded(module))
  end

  defp start_meshx_runtime do
    data_dir = System.get_env("MESHX_STORE_DATA_DIR") || mobile_data_dir()

    if data_dir do
      Application.put_env(:meshx_store, :data_dir, data_dir)
    end

    case Application.ensure_all_started(:meshx_runtime) do
      {:ok, started} ->
        Logger.info("meshx_mobile_app: meshx_runtime started (#{length(started)} apps)")
        rt_probe(:runtime, :meshx_runtime_started, %{started_apps: length(started)})

      {:error, reason} ->
        Logger.error("meshx_mobile_app: meshx_runtime failed to start: #{inspect(reason)}")
        rt_probe(:runtime, :meshx_runtime_start_failed, %{reason: inspect(reason)})
    end
  end

  defp mobile_data_dir do
    case System.get_env("MOB_DATA_DIR") do
      nil -> nil
      dir -> Path.join(dir, "meshx_store")
    end
  end

  defp rt_probe(phase, event, metadata) do
    MeshxMobileApp.BLE.Observability.probe(phase, event, metadata)
  end

  defp safe_platform do
    :mob_nif.platform()
  rescue
    _ -> :unknown
  end
end
