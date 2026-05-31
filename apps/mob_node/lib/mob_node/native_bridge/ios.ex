defmodule Mob.Node.NativeBridge.IOS do
  @moduledoc """
  iOS BLE adapter — thin translation only.

  Selected only inside the Mob iOS runtime. The CoreBluetooth NIF
  delivers raw events to the owner; canonical normalization happens
  in `Mob.Node.BLE.BridgeProtocol`. This module never inspects,
  classifies, or filters events.

  Roadmap: when the statically-linked NIF starts emitting the v1 wire
  format (`%{v: 1, event: ...}`) directly, the legacy-tuple decode
  clauses in `BridgeProtocol` go away and this module needs no change.
  """

  @behaviour Mob.Node.BLE.Adapter

  @impl true
  def start_scan(owner), do: :mob_ble_nif.start_scan(owner)

  @impl true
  def start_advertising(owner, local_name),
    do: :mob_ble_nif.start_advertising(owner, local_name)

  @impl true
  def stop(owner), do: :mob_ble_nif.stop(owner)

  @impl true
  def send_to_peer(owner, peer_id, payload),
    do: :mob_ble_nif.send_ping(owner, peer_id, payload)
end
