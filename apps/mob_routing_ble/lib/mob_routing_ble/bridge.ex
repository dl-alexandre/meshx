defmodule Mob.Routing.BLE.Bridge do
  @moduledoc """
  Behaviour for native/mobile BLE bridge implementations (MeshX adapter contract).

  This is a **kept-in-sync local copy** of the canonical contract.

  **Canonical definition (authoritative for the contract):**
  `Mob.Ble.Bridge` in the `mob_ble` Hex package (see `apps/mob_ble/lib/mob/ble/bridge.ex`).

  The three callbacks and the inbound `{:ble_peer_up, ...}`, `{:ble_peer_down, ...}`,
  `{:ble_frame, ...}` event convention are identical. `Mob.Routing.BLE` performs
  only dynamic calls against the supplied bridge module and therefore accepts
  either behaviour declaration.

  `Mob.Routing.BLE.PortBridge` provides a production boundary for launching
  those native adapters as supervised external processes.

  Desktop / custom bridges (e.g. BlueZ) should continue to declare
  `@behaviour Mob.Routing.BLE.Bridge` for MeshX-centric code.

  Mobile production use should prefer `Mob.Ble.Bridge` + `Mob.Ble.MobileBridge`
  via the `mob_ble` plugin (see docs/BLE_BRIDGE.md and docs/mob_ble_bridge_migration.md).
  """

  # CONTRACT SYNC: Mob.Ble.Bridge <-> Mob.Routing.BLE.Bridge
  # This file contains the MeshX-side copy of the behaviour.
  # The rich, primary moduledoc and ownership lives in Mob.Ble.Bridge
  # (owned by mob_ble package, no mob_* dependency).
  # ANY change to callback signatures or documented inbound event tuples
  # MUST be applied to BOTH files in lockstep.
  # Last synchronized: 2026-05-19
  # See docs/mob_ble_bridge_migration.md (Phase 1) for full rationale,
  # compatibility guarantees, and risk mitigations (API drift prevention).

  @callback start_link(keyword()) :: GenServer.on_start()
  @callback send_frame(pid(), term(), binary(), keyword()) :: :ok | {:error, term()}
  @callback broadcast_frame(pid(), binary(), keyword()) :: :ok | {:error, term()}
end
