defmodule Mob.Node.BLE.LocalRoutingDryRun do
  @moduledoc """
  Dry-run evaluation for local route-candidate selections.

  This converts a `LocalRoutingTable.Selection` into an auditable intent-like
  outcome without forwarding anything. It is a read-model/evidence boundary
  only: it does not route, forward, persist, scan, advertise, fetch, ACK,
  retry, encrypt, authenticate, or run background work.
  """

  alias Mob.Node.BLE.LocalRoutingTable

  @blocked_claims [
    :route_table_available,
    :route_selection_available,
    :live_forwarding_service,
    :routed_delivery,
    :guaranteed_delivery,
    :ack_backed_delivery,
    :retry_backed_delivery,
    :multi_hop_hardware_routing
  ]

  @spec evaluate(LocalRoutingTable.Selection.t() | term(), keyword()) :: map()
  def evaluate(selection, opts \\ [])

  def evaluate(
        %LocalRoutingTable.Selection{status: :selected, selected: selected} = selection,
        opts
      )
      when not is_nil(selected) do
    %{
      dry_run_version: 1,
      boundary: :local_routing_dry_run,
      status: :would_select_candidate,
      destination_peer_id: selection.destination_peer_id,
      next_hop_peer_id: selected.next_hop_peer_id,
      target_device_ids: selected.target_device_ids,
      evaluated_at: Keyword.get(opts, :evaluated_at),
      route_selection_claim_allowed?: false,
      forwarding_claim_allowed?: false,
      routed_delivery_claim_allowed?: false,
      executed?: false,
      blocked_claims: @blocked_claims,
      notes: [
        "Dry-run selected an observation candidate only.",
        "No forwarding intent was enqueued or executed.",
        "Routed-delivery claims remain blocked."
      ]
    }
  end

  def evaluate(%LocalRoutingTable.Selection{} = selection, opts) do
    %{
      dry_run_version: 1,
      boundary: :local_routing_dry_run,
      status: :no_forwardable_route,
      destination_peer_id: selection.destination_peer_id,
      next_hop_peer_id: nil,
      target_device_ids: [],
      evaluated_at: Keyword.get(opts, :evaluated_at),
      blocked_reasons: selection.blocked_reasons,
      route_selection_claim_allowed?: false,
      forwarding_claim_allowed?: false,
      routed_delivery_claim_allowed?: false,
      executed?: false,
      blocked_claims: @blocked_claims,
      notes: [
        "Dry-run found no forwardable observation candidate.",
        "No forwarding intent was enqueued or executed.",
        "This is not a routing failure because production routing is not enabled."
      ]
    }
  end

  def evaluate(_selection, opts) do
    %{
      dry_run_version: 1,
      boundary: :local_routing_dry_run,
      status: :invalid_selection,
      destination_peer_id: nil,
      next_hop_peer_id: nil,
      target_device_ids: [],
      evaluated_at: Keyword.get(opts, :evaluated_at),
      blocked_reasons: [:invalid_selection],
      route_selection_claim_allowed?: false,
      forwarding_claim_allowed?: false,
      routed_delivery_claim_allowed?: false,
      executed?: false,
      blocked_claims: @blocked_claims,
      notes: [
        "Invalid routing selections are rejected before dry-run evaluation."
      ]
    }
  end

  @spec snapshot([LocalRoutingTable.Selection.t()] | [term()], keyword()) :: map()
  def snapshot(selections, opts \\ []) when is_list(selections) do
    outcomes = Enum.map(selections, &evaluate(&1, opts))

    %{
      dry_run_version: 1,
      boundary: :local_routing_dry_run_snapshot,
      outcome_count: length(outcomes),
      would_select_candidate_count: Enum.count(outcomes, &(&1.status == :would_select_candidate)),
      no_forwardable_route_count: Enum.count(outcomes, &(&1.status == :no_forwardable_route)),
      invalid_selection_count: Enum.count(outcomes, &(&1.status == :invalid_selection)),
      forwarding_claim_allowed?: false,
      routed_delivery_claim_allowed?: false,
      outcomes: outcomes,
      blocked_claims: @blocked_claims,
      notes: [
        "Dry-run routing evidence is observation planning only.",
        "No forwarding service, delivery semantics, ACKs, retries, or multi-hop hardware routing are present."
      ]
    }
  end

  @spec json_snapshot([LocalRoutingTable.Selection.t()] | [term()], keyword()) :: map()
  def json_snapshot(selections, opts \\ []) do
    selections
    |> snapshot(opts)
    |> JSON.encode!()
    |> JSON.decode!()
  end
end
