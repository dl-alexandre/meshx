defmodule Mob.Node.NativeBridge do
  @moduledoc """
  Back-compat shim — the bridge contract now lives in
  `Mob.Node.BLE.Adapter`. This module is kept as a tiny
  delegation surface so callers configured via
  `Application.put_env(:mob_node, :native_bridge, ...)` keep
  resolving. New code should depend on `BLE.Adapter` directly.
  """

  alias Mob.Node.BLE.Adapter

  @spec configured() :: module()
  def configured do
    Application.get_env(:mob_node, :native_bridge, Adapter.configured())
  end
end
