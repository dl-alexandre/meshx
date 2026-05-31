defmodule Mob.Node.BLE.LocalInboxActionSummaryTest do
  use ExUnit.Case, async: true

  alias Mob.Node.BLE.{
    BeaconRef,
    LocalInbox,
    LocalInboxActionSummary,
    MessageEnvelope
  }

  alias Mob.Node.BLE.Events.{ReceivedMessage, ReceivedMessageBeacon}

  defp envelope(opts \\ []) do
    {:ok, envelope} =
      MessageEnvelope.build(
        Keyword.merge(
          [
            message_id: <<1::128>>,
            sender_peer_id: "meshx-alpha",
            recipient_peer_id: "meshx-beta",
            created_at: 1_700_000_000_000,
            ttl: 1,
            payload_type: "TX",
            payload: "hello",
            capability_requirements: 0
          ],
          opts
        )
      )

    envelope
  end

  defp full_event(env) do
    %ReceivedMessage{
      message_id: env.message_id,
      sender_peer_id: env.sender_peer_id,
      recipient_peer_id: env.recipient_peer_id,
      received_device_id: "AA:01",
      received_at: 100,
      rssi: -60,
      envelope: env,
      raw_transport_metadata: %{}
    }
  end

  defp beacon_event(env, opts \\ []) do
    %ReceivedMessageBeacon{
      beacon_version: 1,
      envelope_version: env.envelope_version,
      payload_kind: env.payload_type,
      message_id_hash: BeaconRef.message_id_hash(env),
      sender_peer_id_hash: Keyword.get(opts, :sender_peer_hash, BeaconRef.sender_peer_hash(env)),
      received_device_id: "AA:02",
      received_at: 90,
      rssi: -70,
      raw_transport_metadata: %{}
    }
  end

  test "summarizes full messages without fetch blockers" do
    env = envelope()

    snapshot =
      LocalInbox.new()
      |> LocalInbox.ingest(full_event(env))
      |> LocalInbox.snapshot()

    assert {:ok, summary} = LocalInboxActionSummary.summarize(snapshot)
    assert summary.nearby_counts.full_message == 1
    assert summary.resolution_counts.full_envelope_present == 1
    assert summary.fetch_intent_count == 0
    assert summary.fetch_intents == []
    assert summary.blockers == []
    assert summary.next_actions == [:show_full_messages]
  end

  test "summarizes unresolved refs as blocked on unvalidated fetch transport" do
    env = envelope()

    snapshot =
      LocalInbox.new()
      |> LocalInbox.ingest(beacon_event(env))
      |> LocalInbox.snapshot()

    assert {:ok, summary} = LocalInboxActionSummary.summarize(snapshot)
    assert summary.nearby_counts.unresolved_ref == 1
    assert summary.resolution_counts.needs_fetch == 1
    assert summary.fetch_intent_count == 0
    assert summary.blockers == [:fetch_transport_not_validated]
    assert summary.next_actions == [:show_unresolved_refs]
  end

  test "optionally includes fetch intents without dispatching them" do
    env = envelope()

    snapshot =
      LocalInbox.new()
      |> LocalInbox.ingest(beacon_event(env))
      |> LocalInbox.snapshot()

    assert {:ok, summary} =
             LocalInboxActionSummary.summarize(snapshot,
               fetch_intents: [
                 now: 1_000,
                 ttl_ms: 5_000,
                 requesting_peer_id: "mob-local",
                 id_fun: fn _ -> "fetch-1" end
               ]
             )

    assert summary.fetch_intent_count == 1

    assert [%{transport_state: :blocked_unvalidated, fetch_request: %{request_id: "fetch-1"}}] =
             summary.fetch_intents

    assert summary.blockers == [:fetch_transport_not_validated, :fetch_intents_not_dispatched]
    assert summary.next_actions == [:show_unresolved_refs, :review_fetch_intents]
  end

  test "unresolvable refs are reported separately from fetch needs" do
    env = envelope()

    snapshot =
      LocalInbox.new()
      |> LocalInbox.ingest(full_event(env))
      |> LocalInbox.ingest(beacon_event(env, sender_peer_hash: <<255::64>>))
      |> LocalInbox.snapshot()

    assert {:ok, summary} = LocalInboxActionSummary.summarize(snapshot)
    assert summary.resolution_counts.unresolvable == 1
    assert summary.fetch_intent_count == 0
    assert summary.blockers == [:unresolvable_refs_present]
    assert summary.next_actions == [:show_full_messages, :review_unresolvable_refs]
  end

  test "invalid fetch intent options fail explicitly" do
    assert {:error, :invalid_fetch_intent_options} =
             LocalInboxActionSummary.summarize(%{nearby_messages: []}, fetch_intents: :yes)
  end
end
