defmodule MeshxMobileApp.App do
  @moduledoc """
  Mob application entry point for the MeshX mobile app.

  The app shell is Mob-first: UI and session state live in Elixir on the
  device, while platform BLE is provided by a native bridge behind
  `MeshxMobileApp.NativeBridge`.
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
    start_meshx_runtime()
    maybe_start_distribution()
    Mob.Screen.start_root(MeshxMobileApp.HomeScreen)
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
      :ok -> Logger.info("meshx_mobile_app: distribution up as #{node}")
      other -> Logger.warning("meshx_mobile_app: distribution not started: #{inspect(other)}")
    end
  rescue
    error -> Logger.warning("meshx_mobile_app: distribution error: #{inspect(error)}")
  end

  defp configure_native_bridge do
    case :mob_nif.platform() do
      :ios ->
        if ble_nif_available?() do
          Application.put_env(:meshx_mobile_app, :native_bridge, MeshxMobileApp.NativeBridge.IOS)
        end

      :android ->
        if ble_nif_available?() do
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

  # Both platform bridges sit behind the same `:meshx_ble_nif` Erlang
  # surface — statically linked on iOS, JNI-backed on Android — so the
  # availability probe is shared.
  defp ble_nif_available? do
    match?({:module, :meshx_ble_nif}, Code.ensure_loaded(:meshx_ble_nif))
  end

  defp start_meshx_runtime do
    if data_dir = System.get_env("MESHX_STORE_DATA_DIR") || mobile_data_dir() do
      Application.put_env(:meshx_store, :data_dir, data_dir)
    end

    case Application.ensure_all_started(:meshx_runtime) do
      {:ok, started} ->
        Logger.info("meshx_mobile_app: meshx_runtime started (#{length(started)} apps)")

      {:error, reason} ->
        Logger.error("meshx_mobile_app: meshx_runtime failed to start: #{inspect(reason)}")
    end
  end

  defp mobile_data_dir do
    case System.get_env("MOB_DATA_DIR") do
      nil -> nil
      dir -> Path.join(dir, "meshx_store")
    end
  end
end
