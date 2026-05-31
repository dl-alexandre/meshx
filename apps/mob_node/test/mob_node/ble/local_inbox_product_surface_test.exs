defmodule Mob.Node.BLE.LocalInboxProductSurfaceTest do
  use ExUnit.Case, async: true

  alias Mob.Node.BLE.{
    LocalInbox,
    LocalInboxProductSurface,
    LocalInboxView,
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

  defp full_event(opts \\ []) do
    env = Keyword.get(opts, :envelope, envelope())

    %ReceivedMessage{
      message_id: env.message_id,
      sender_peer_id: env.sender_peer_id,
      recipient_peer_id: env.recipient_peer_id,
      received_device_id: Keyword.get(opts, :received_device_id, "AA:01"),
      received_at: Keyword.get(opts, :received_at, 100),
      rssi: Keyword.get(opts, :rssi, -60),
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

  test "groups nearby messages into explicit product sections" do
    surface = LocalInboxProductSurface.build(snapshot())

    assert surface.title == "Nearby Messages"
    assert surface.state_order == [:full_message, :unresolved_ref, :gossiped_ref, :stale_ref]

    assert %{
             full_message: 1,
             unresolved_ref: 1,
             gossiped_ref: 1,
             stale_ref: 1
           } = surface.counts_by_state

    assert [
             %{state: :full_message, label: "Full messages", count: 1},
             %{state: :unresolved_ref, label: "Unresolved refs", count: 1},
             %{state: :gossiped_ref, label: "Gossiped refs", count: 1},
             %{state: :stale_ref, label: "Stale refs", count: 1}
           ] = surface.sections

    assert Enum.any?(
             surface.state_copy,
             &(&1.state == :gossiped_ref and &1.limitation =~ "not guaranteed delivery")
           )
  end

  test "carries filter, sort, and detail affordances" do
    base = snapshot()

    [ref] =
      LocalInboxProductSurface.build(base, states: [:unresolved_ref]).sections
      |> Enum.at(1)
      |> Map.fetch!(:items)

    surface =
      LocalInboxProductSurface.build(base,
        states: [:unresolved_ref],
        payload_kinds: ["TX"],
        source_device_id: "AA:02",
        sort: :strongest_rssi,
        detail_message_key: ref.message_key
      )

    assert surface.active_filters.states == [:unresolved_ref]
    assert surface.active_filters.payload_kinds == ["TX"]
    assert surface.active_filters.source_device_id == "AA:02"
    assert surface.sort == :strongest_rssi
    assert surface.available_filters.payload_kinds == ["AL", "TX"]
    assert surface.available_filters.source_device_ids == ["AA:01", "AA:02", "AA:03", "AA:04"]
    assert {:ok, ^ref} = surface.selected_detail
    assert surface.selected_detail_summary.message_key == ref.message_key
    assert surface.selected_detail_summary.state == :unresolved_ref
    assert surface.selected_detail_summary.title == "Unresolved beacon ref"
    assert surface.selected_detail_summary.limitation =~ "pointer"
    assert surface.selected_detail_summary.next_action =~ "validated fetch transport"
    assert "not fetch success" in surface.selected_detail_summary.blocked_claims
    refute surface.selected_detail_summary.delivery_claim_allowed?
  end

  test "unknown sort falls back to the default product ordering" do
    surface = LocalInboxProductSurface.build(snapshot(), sort: :unknown_sort)

    assert surface.sort == :state_then_recent

    assert [:full_message, :unresolved_ref, :gossiped_ref, :stale_ref] =
             surface.sections
             |> Enum.flat_map(& &1.items)
             |> Enum.map(& &1.state)
  end

  test "freshness options keep product counts and details stale-aware" do
    raw_snapshot = Map.delete(snapshot(), :nearby_messages)

    surface =
      LocalInboxProductSurface.build(raw_snapshot,
        states: [:stale_ref],
        now: 100,
        stale_after_ms: 10
      )

    assert surface.counts_by_state.stale_ref == 1
    assert surface.counts_by_state.unresolved_ref == 1
    assert [%{state: :stale_ref} = stale] = Enum.at(surface.sections, 3).items

    detail_surface =
      LocalInboxProductSurface.build(raw_snapshot,
        detail_message_key: stale.message_key,
        now: 100,
        stale_after_ms: 10
      )

    assert {:ok, %{state: :stale_ref}} = detail_surface.selected_detail
    assert detail_surface.selected_detail_summary.state == :stale_ref
    assert detail_surface.selected_detail_summary.limitation =~ "Stale beacon ref"
  end

  test "keeps unresolved beacon limitations visible" do
    surface = LocalInboxProductSurface.build(snapshot())

    assert Enum.any?(surface.notes, &String.contains?(&1, "pointers"))
    assert Enum.any?(surface.notes, &String.contains?(&1, "not guaranteed delivery"))
  end
end
