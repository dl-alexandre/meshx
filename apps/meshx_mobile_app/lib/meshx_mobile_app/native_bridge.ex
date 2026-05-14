defmodule MeshxMobileApp.NativeBridge do
  @moduledoc """
  Back-compat shim — the bridge contract now lives in
  `MeshxMobileApp.BLE.Adapter`. This module is kept as a tiny
  delegation surface so callers configured via
  `Application.put_env(:meshx_mobile_app, :native_bridge, ...)` keep
  resolving. New code should depend on `BLE.Adapter` directly.
  """

  alias MeshxMobileApp.BLE.Adapter

  @spec configured() :: module()
  def configured do
    Application.get_env(:meshx_mobile_app, :native_bridge, Adapter.configured())
  end
end
