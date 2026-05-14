defmodule MeshxMobileApp.App do
  @moduledoc """
  Mob application entry point for the MeshX mobile app.

  The app shell is Mob-first: UI and session state live in Elixir on the
  device, while platform BLE is provided by a native bridge behind
  `MeshxMobileApp.NativeBridge`.
  """

  use Mob.App

  @impl Mob.App
  def navigation(_platform) do
    stack(:meshx, root: MeshxMobileApp.HomeScreen, title: "MeshX")
  end

  @impl Mob.App
  def on_start do
    configure_native_bridge()
    start_meshx_runtime()
    Mob.Screen.start_root(MeshxMobileApp.HomeScreen)
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

    Application.ensure_all_started(:meshx_runtime)
  end

  defp mobile_data_dir do
    case System.get_env("MOB_DATA_DIR") do
      nil -> nil
      dir -> Path.join(dir, "meshx_store")
    end
  end
end
