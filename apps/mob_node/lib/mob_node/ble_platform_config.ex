defmodule Mob.Node.BlePlatformConfig do
  @moduledoc """
  Keeps `:ble_adapter` and `:native_bridge` in sync for platform BLE.

  `Mob.Node.Session` reads `Mob.Node.BLE.Adapter.configured/0` (`:ble_adapter`).
  Setting only `:native_bridge` (the pre-migration key) leaves the UI on
  `NativeBridge.Noop` while logs show a platform bridge — a silent production bug.
  """

  @spec apply_from_platform(atom(), boolean()) :: :ok
  def apply_from_platform(:ios, true), do: put_ble_adapter(Mob.Node.NativeBridge.IOS)
  def apply_from_platform(:android, true), do: put_ble_adapter(Mob.Node.NativeBridge.Android)
  def apply_from_platform(_platform, _nif_loaded?), do: :ok

  @spec put_ble_adapter(module()) :: :ok
  def put_ble_adapter(module) when is_atom(module) do
    Application.put_env(:mob_node, :native_bridge, module)
    Application.put_env(:mob_node, :ble_adapter, module)
    :ok
  end
end