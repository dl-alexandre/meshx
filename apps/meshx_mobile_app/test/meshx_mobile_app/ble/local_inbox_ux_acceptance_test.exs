defmodule MeshxMobileApp.BLE.LocalInboxUxAcceptanceTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.{
    LocalInbox,
    LocalInboxUxAcceptance,
    LocalInboxView,
    MessageEnvelope
  }

  alias MeshxMobileApp.BLE.Events.{ReceivedMessage, ReceivedMessageBeacon}

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

  defp full_event do
    env = envelope()

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

  defp beacon_event(opts \\ []) do
    %ReceivedMessageBeacon{
      beacon_version: 1,
      envelope_version: 1,
      payload_kind: Keyword.get(opts, :payload_kind, "TX"),
      message_id_hash: Keyword.get(opts, :message_id_hash, <<2, 2, 2, 2, 2, 2, 2, 2>>),
      sender_peer_id_hash: Keyword.get(opts, :sender_peer_id_hash, <<3, 3, 3, 3, 3, 3, 3, 3>>),
      received_device_id: Keyword.get(opts, :received_device_id, "AA:02"),
      received_at: Keyword.get(opts, :received_at, 90),
      rssi: Keyword.get(opts, :rssi, -70),
      raw_transport_metadata: Keyword.get(opts, :raw_transport_metadata, %{})
    }
  end

  defp snapshot do
    stale =
      beacon_event(
        message_id_hash: <<4, 4, 4, 4, 4, 4, 4, 4>>,
        sender_peer_id_hash: <<5, 5, 5, 5, 5, 5, 5, 5>>,
        received_device_id: "AA:03",
        received_at: 1,
        rssi: -90,
        payload_kind: "AL"
      )

    gossip =
      beacon_event(
        message_id_hash: <<6, 6, 6, 6, 6, 6, 6, 6>>,
        sender_peer_id_hash: <<7, 7, 7, 7, 7, 7, 7, 7>>,
        received_device_id: "AA:04",
        received_at: 95,
        rssi: -50,
        raw_transport_metadata: %{transport: :advert_gossip_simulation}
      )

    base =
      LocalInbox.new()
      |> LocalInbox.ingest(full_event())
      |> LocalInbox.ingest(beacon_event())
      |> LocalInbox.ingest(gossip)
      |> LocalInbox.ingest(stale)
      |> LocalInbox.snapshot()

    Map.put(
      base,
      :nearby_messages,
      LocalInboxView.nearby_messages(base, now: 100, stale_after_ms: 10)
    )
  end

  test "acceptance snapshot verifies pure surface gates and blocks production UX claim" do
    acceptance = LocalInboxUxAcceptance.snapshot(snapshot(), now: 100, stale_after_ms: 10)

    assert acceptance.surface == :nearby_messages
    assert acceptance.satisfied_count == 7
    assert acceptance.blocked_count == 1
    refute acceptance.production_ux_claim_allowed?

    assert [
             %{id: :state_filters, status: :satisfied},
             %{id: :sort_controls, status: :satisfied},
             %{id: :control_summaries, status: :satisfied},
             %{id: :state_rows, status: :satisfied},
             %{id: :detail_panels, status: :satisfied},
             %{id: :blocked_claim_copy, status: :satisfied},
             %{id: :blocked_claim_warnings, status: :satisfied},
             %{id: :on_device_validation, status: :blocked}
           ] = acceptance.gates

    assert Enum.any?(
             List.last(acceptance.gates).missing,
             &String.contains?(&1, "Run the Mob Nearby Messages surface on target hardware")
           )

    assert Enum.any?(
             List.last(acceptance.gates).evidence,
             &String.contains?(&1, "LocalInboxUxValidationPlan")
           )
  end

  test "row and detail acceptance blocks when required states are absent" do
    acceptance =
      %{nearby_messages: [hd(snapshot().nearby_messages)]}
      |> LocalInboxUxAcceptance.snapshot()

    assert %{id: :state_rows, status: :blocked, missing: row_missing} =
             Enum.find(acceptance.gates, &(&1.id == :state_rows))

    assert "Missing complete row for :unresolved_ref." in row_missing
    assert "Missing complete row for :gossiped_ref." in row_missing
    assert "Missing complete row for :stale_ref." in row_missing

    assert %{id: :detail_panels, status: :blocked, missing: detail_missing} =
             Enum.find(acceptance.gates, &(&1.id == :detail_panels))

    assert "Missing detail panel coverage for :unresolved_ref." in detail_missing

    assert %{id: :blocked_claim_copy, status: :blocked, missing: copy_missing} =
             Enum.find(acceptance.gates, &(&1.id == :blocked_claim_copy))

    assert "Missing row blocked-claim copy for :unresolved_ref." in copy_missing
    assert "Missing detail blocked-claim copy for :unresolved_ref." in copy_missing
  end

  test "local inbox snapshot embeds UX acceptance without claiming production readiness" do
    snapshot = LocalInbox.new() |> LocalInbox.ingest(full_event()) |> LocalInbox.snapshot()

    assert %{ux_acceptance: acceptance} = snapshot
    refute acceptance.production_ux_claim_allowed?

    assert Enum.any?(
             acceptance.gates,
             &(&1.id == :on_device_validation and &1.status == :blocked)
           )
  end
end
