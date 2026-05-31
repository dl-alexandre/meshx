defmodule Mob.Node.NativeBridge.Android do
  @moduledoc """
  Android BLE adapter — thin translation only.

  Selected only inside the Mob Android runtime. The counterpart of the
  iOS CoreBluetooth NIF: on Android the `:mob_ble_nif` Erlang
  surface is backed by a JNI shim into the Kotlin BLE layer
  (`mob.ble`). The Kotlin `BeamEventSink` forwards v1
  wire-format maps to the owner pid; canonical normalization happens in
  `Mob.Node.BLE.BridgeProtocol`. This module never inspects,
  classifies, or filters events.

  The Erlang-facing contract is identical to
  `Mob.Node.NativeBridge.IOS` by design — the platform difference
  (statically-linked CoreBluetooth NIF vs. JNI-backed `BluetoothLe*`
  wrappers) lives entirely below `:mob_ble_nif`.

  Roadmap: when the JNI NIF starts emitting the v1 wire format
  (`%{v: 1, event: ...}`) directly, the legacy-tuple decode clauses in
  `BridgeProtocol` go away and this module needs no change.
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
