defmodule MeshxMobileApp.BLE.LocalIOSAdvertCarrierDecision do
  @moduledoc """
  Thin facade over `Mob.Ble.Internal.CarrierDecision`.

  The canonical carrier policy ledger now lives in the `mob_ble` package
  (`Mob.Ble.Internal.CarrierDecision`). This module remains as a stable
  app-layer alias for callers that predate the move (parity manifest,
  scenario plan, readiness/completion audits) and to preserve the public
  name referenced in those evidence documents.

  Do not add data here. Edit the canonical module in `mob_ble` instead.
  """

  alias Mob.Ble.Internal.CarrierDecision

  @spec carriers() :: [CarrierDecision.Carrier.t()]
  defdelegate carriers(), to: CarrierDecision

  @spec snapshot() :: map()
  defdelegate snapshot(), to: CarrierDecision

  @doc """
  Snapshot round-tripped through JSON encode/decode — useful for fixtures
  and evidence manifests that need string-keyed maps.
  """
  @spec json_snapshot() :: map()
  def json_snapshot do
    snapshot()
    |> JSON.encode!()
    |> JSON.decode!()
  end
end
