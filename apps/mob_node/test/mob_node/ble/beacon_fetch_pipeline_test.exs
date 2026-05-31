defmodule Mob.Node.BLE.BeaconFetchPipelineTest do
  use ExUnit.Case, async: true

  alias Mob.Node.BLE.{
    BeaconFetchAttemptLedger,
    BeaconFetchPlanner,
    BeaconFetchRequest,
    BeaconRef,
    PeerCapabilities
  }

  alias Mob.Node.BLE.BeaconFetchAttemptLedger.FetchAttempt
  alias Mob.Node.BLE.BeaconFetchDispatcher.DryRun
  alias Mob.Node.BLE.PeerInventory.PeerSummary

  defp request(opts \\ []) do
    %BeaconFetchRequest{
      request_id: Keyword.get(opts, :request_id, "fetch-1"),
      message_id_hash: Keyword.get(opts, :message_id_hash, <<1::64>>),
      sender_peer_hash:
        Keyword.get(
          opts,
          :sender_peer_hash,
          BeaconRef.sender_peer_hash(envelope_like("meshx-alpha"))
        ),
      requesting_peer_id: Keyword.get(opts, :requesting_peer_id),
      candidate_source_peer_ids: Keyword.get(opts, :candidate_source_peer_ids, []),
      observed_at: Keyword.get(opts, :observed_at, 10_000),
      expires_at: Keyword.get(opts, :expires_at, 20_000),
      reason: :legacy_beacon_ref
    }
  end

  defp envelope_like(peer_id) do
    %Mob.Node.BLE.MessageEnvelope{
      message_id: <<0::128>>,
      sender_peer_id: peer_id,
      created_at: 0,
      payload_type: "TX"
    }
  end

  defp caps(mob? \\ true) do
    if mob? do
      %PeerCapabilities{protocol_version: 1, supports_replay_contract: true}
    else
      %PeerCapabilities{}
    end
  end

  defp summary(peer_id, opts \\ []) do
    %PeerSummary{
      peer_id: peer_id,
      device_ids: Keyword.get(opts, :device_ids, ["dev-#{peer_id}"]),
      display_name: peer_id || "anonymous",
      identity_confidence: Keyword.get(opts, :identity_confidence, :advertised),
      identity_source: :advertised_name,
      capabilities: Keyword.get(opts, :capabilities, caps()),
      presence: Keyword.get(opts, :presence, :active),
      first_seen_at: 0,
      last_seen_at: Keyword.get(opts, :last_seen_at, 100),
      last_rssi: -50,
      advertisement_seen_count: 1,
      collision_count: 0,
      last_conflicting_peer_id: nil,
      anonymous?: is_nil(peer_id),
      suspicious?: false
    }
  end

  test "candidate selection prefers sender hash, MeshX capability, confidence, and recency deterministically" do
    request = request(candidate_source_peer_ids: [])

    candidates =
      BeaconFetchPlanner.select(request, [
        summary("mob-stale", presence: :stale, last_seen_at: 999),
        summary("meshx-beta", capabilities: caps(false), last_seen_at: 900),
        summary("meshx-alpha", identity_confidence: :advertised, last_seen_at: 100),
        summary("mob-verified", identity_confidence: :verified, last_seen_at: 300),
        summary(nil, last_seen_at: 1_000)
      ])

    assert Enum.map(candidates, & &1.peer_id) == [
             "meshx-alpha",
             "mob-verified",
             "meshx-beta"
           ]

    assert hd(candidates).rank.sender_hash_match == true
  end

  test "explicit candidate source list constrains candidates and empty list is explicit all-known mode" do
    summaries = [
      summary("meshx-alpha", last_seen_at: 100),
      summary("meshx-beta", last_seen_at: 200)
    ]

    assert ["meshx-beta"] =
             request(candidate_source_peer_ids: ["meshx-beta"])
             |> BeaconFetchPlanner.select(summaries)
             |> Enum.map(& &1.peer_id)

    assert ["meshx-alpha", "meshx-beta"] =
             request(candidate_source_peer_ids: [])
             |> BeaconFetchPlanner.select(summaries)
             |> Enum.map(& &1.peer_id)
  end

  test "fetch attempt ledger turns selected candidates into immutable planned intents" do
    request = request()
    candidates = BeaconFetchPlanner.select(request, [summary("meshx-alpha")])

    assert [
             %FetchAttempt{
               fetch_attempt_id: "fetch-att-0",
               request_id: "fetch-1",
               message_id_hash: <<1::64>>,
               target_peer_id: "meshx-alpha",
               target_device_ids: ["dev-meshx-alpha"],
               planned_at: 30_000,
               status: :planned
             }
           ] =
             BeaconFetchAttemptLedger.record(request, candidates,
               planned_at: 30_000,
               id_fun: fn i -> "fetch-att-#{i}" end
             )
  end

  test "dry-run fetch dispatcher reports would_fetch, skipped, invalid_request, and no_candidates" do
    valid = %FetchAttempt{
      fetch_attempt_id: "fetch-att-0",
      request_id: "fetch-1",
      message_id_hash: <<1::64>>,
      target_peer_id: "meshx-alpha",
      target_device_ids: ["dev-alpha"],
      planned_at: 1
    }

    invalid = %{valid | fetch_attempt_id: ""}

    assert [%{kind: :would_fetch, adapter: :fetch_dry_run}] =
             DryRun.dispatch([valid], outcome_at: 40_000)

    assert [%{kind: :skipped, reason: :skip_predicate}] =
             DryRun.dispatch([valid], outcome_at: 40_000, skip?: fn _ -> true end)

    assert [%{kind: :invalid_request, reason: :validation}] =
             DryRun.dispatch([invalid], outcome_at: 40_000)

    assert [
             %{
               kind: :no_candidates,
               reason: :empty_candidates,
               request_id: "fetch-1",
               message_id_hash: <<1::64>>
             }
           ] =
             DryRun.dispatch([],
               outcome_at: 40_000,
               request_id: "fetch-1",
               message_id_hash: <<1::64>>
             )
  end

  test "legacy beacon unresolved state flows through planning, ledger, and dry-run outcomes" do
    request = request(candidate_source_peer_ids: ["meshx-alpha"])
    candidates = BeaconFetchPlanner.select(request, [summary("meshx-alpha")])
    attempts = BeaconFetchAttemptLedger.record(request, candidates, planned_at: 30_000)

    assert [%{kind: :would_fetch, request_id: "fetch-1", target_peer_id: "meshx-alpha"}] =
             DryRun.dispatch(attempts, outcome_at: 40_000)
  end
end
