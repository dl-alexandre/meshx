defmodule Mob.Node.BLE.LocalInboxNativeSurfaceTest do
  use ExUnit.Case, async: true

  alias Mob.Node.BLE.{
    LocalInbox,
    LocalInboxNativeSurface,
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

  test "builds native state filters, sort options, and rows" do
    surface = LocalInboxNativeSurface.build(snapshot(), selected_state: :all)

    refute surface.empty?
    assert surface.title == "Nearby Messages"
    assert surface.empty_label == "No nearby messages"
    assert surface.summary_line == "4 nearby | full 1 | refs 1 | gossip 1 | stale 1"
    assert surface.filter_summary == "Showing all nearby observations (4)."
    assert surface.sort_summary == "Full messages, refs, gossip, then stale"
    assert surface.selected_state == :all
    assert surface.selected_sort == :state_then_recent

    assert [
             %{state: :all, label: "All", count: 4, selected?: true},
             %{state: :full_message, short_label: "Full", count: 1},
             %{state: :unresolved_ref, short_label: "Ref", count: 1},
             %{state: :gossiped_ref, short_label: "Gossip", count: 1},
             %{state: :stale_ref, short_label: "Stale", count: 1}
           ] = surface.state_filters

    assert Enum.any?(
             surface.sort_options,
             &(&1.sort == :strongest_rssi and &1.description == "Strongest signal first")
           )

    assert Enum.any?(surface.state_copy, &(&1.state == :unresolved_ref))

    assert [
             %{
               state: :full_message,
               label: "Full messages",
               count: 1,
               rows: [%{state: :full_message}]
             },
             %{
               state: :unresolved_ref,
               label: "Unresolved refs",
               count: 1,
               rows: [%{state: :unresolved_ref}]
             },
             %{
               state: :gossiped_ref,
               label: "Gossiped refs",
               count: 1,
               rows: [%{state: :gossiped_ref}]
             },
             %{state: :stale_ref, label: "Stale refs", count: 1, rows: [%{state: :stale_ref}]}
           ] = surface.sections

    assert [
             %{
               state: :full_message,
               badge: "full",
               severity: :ready,
               unresolved?: false,
               trust_summary: "Unsigned local observation",
               trusted_message?: false
             },
             %{
               state: :unresolved_ref,
               badge: "ref",
               severity: :needs_transport,
               unresolved?: true,
               trust_summary: "Untrusted hash reference",
               trusted_message?: false,
               blocked_claims: unresolved_blocked_claims
             },
             %{
               state: :gossiped_ref,
               badge: "gossip",
               severity: :informational,
               unresolved?: true,
               blocked_claims: gossiped_blocked_claims
             },
             %{state: :stale_ref, badge: "stale", severity: :stale, stale?: true}
           ] = surface.rows

    assert "not full message delivery" in unresolved_blocked_claims
    assert "not multi-hop hardware proof" in gossiped_blocked_claims
  end

  test "selected state narrows rows while keeping global counts visible" do
    surface =
      LocalInboxNativeSurface.build(snapshot(),
        selected_state: :gossiped_ref,
        sort: :strongest_rssi
      )

    assert surface.selected_state == :gossiped_ref
    assert surface.selected_sort == :strongest_rssi
    assert surface.summary_line == "4 nearby | full 1 | refs 1 | gossip 1 | stale 1"
    assert surface.filter_summary == "Showing gossiped refs only (1)."
    assert surface.sort_summary == "Strongest signal first"
    assert [%{state: :gossiped_ref}] = surface.rows
    assert Enum.find(surface.state_filters, &(&1.state == :all)).count == 4
    assert Enum.find(surface.state_filters, &(&1.state == :gossiped_ref)).selected?
    assert Enum.find(surface.sort_options, &(&1.sort == :strongest_rssi)).selected?
  end

  test "unknown controls fall back to the default safe product view" do
    surface =
      LocalInboxNativeSurface.build(snapshot(),
        selected_state: :unknown_state,
        sort: :unknown_sort
      )

    refute surface.empty?
    assert surface.selected_state == :all
    assert surface.selected_sort == :state_then_recent
    assert surface.filter_summary == "Showing all nearby observations (4)."
    assert surface.sort_summary == "Full messages, refs, gossip, then stale"
    assert Enum.find(surface.state_filters, &(&1.state == :all)).selected?
    assert Enum.find(surface.sort_options, &(&1.sort == :state_then_recent)).selected?
  end

  test "freshness options classify stale refs without precomputed nearby messages" do
    raw_snapshot = Map.delete(snapshot(), :nearby_messages)

    surface =
      LocalInboxNativeSurface.build(raw_snapshot,
        selected_state: :stale_ref,
        now: 100,
        stale_after_ms: 10
      )

    assert surface.summary_line == "4 nearby | full 1 | refs 1 | gossip 1 | stale 1"
    assert surface.filter_summary == "Showing stale refs only (1)."
    assert [%{state: :stale_ref, stale?: true, unresolved?: true} = stale] = surface.rows

    detail_surface =
      LocalInboxNativeSurface.build(raw_snapshot,
        detail_message_key: stale.message_key,
        now: 100,
        stale_after_ms: 10
      )

    assert detail_surface.detail.state == :stale_ref
    assert detail_surface.detail.limitation =~ "Stale beacon ref"
    refute detail_surface.detail.delivery_claim_allowed?
  end

  test "detail panel carries selected item limitations without claiming delivery" do
    [ref] =
      LocalInboxNativeSurface.build(snapshot(), selected_state: :unresolved_ref).rows

    surface = LocalInboxNativeSurface.build(snapshot(), detail_message_key: ref.message_key)

    assert %{status: :selected, state: :unresolved_ref} = surface.detail
    assert surface.detail.detail_title == "Unresolved beacon ref"
    assert surface.detail.limitation =~ "pointer"
    assert surface.detail.next_action =~ "validated fetch transport"
    assert surface.detail.message_id_hash == <<2, 2, 2, 2, 2, 2, 2, 2>>
    assert surface.detail.sender_peer_hash == <<3, 3, 3, 3, 3, 3, 3, 3>>
    assert "Message hash: 02020202" in surface.detail.detail_lines
    assert "Sender hash: 03030303" in surface.detail.detail_lines
    assert "Observed via: direct advertisement" in surface.detail.detail_lines
    assert surface.detail.trust_summary == "Untrusted hash reference"
    assert :full_envelope_resolution in surface.detail.required_before_trusted
    assert "Trust: Untrusted hash reference" in surface.detail.detail_lines

    assert Enum.any?(
             surface.detail.detail_lines,
             &String.starts_with?(&1, "Required before trusted: full_envelope_resolution")
           )

    assert "not fetch success" in surface.detail.blocked_claims
    assert Enum.any?(surface.detail.detail_lines, &String.contains?(&1, "Blocked claims:"))
    refute surface.detail.delivery_claim_allowed?
    assert Enum.find(surface.rows, &(&1.message_key == ref.message_key)).selected?
  end

  test "detail panel distinguishes full envelopes from gossiped refs" do
    [full] =
      LocalInboxNativeSurface.build(snapshot(), selected_state: :full_message).rows

    full_surface = LocalInboxNativeSurface.build(snapshot(), detail_message_key: full.message_key)

    assert full_surface.detail.message_id == <<1::128>>
    assert full_surface.detail.sender_peer_id == "meshx-alpha"
    assert "Message ID: 00000000" in full_surface.detail.detail_lines
    assert "Sender: meshx-alpha" in full_surface.detail.detail_lines
    assert "Recipient: meshx-beta" in full_surface.detail.detail_lines

    [gossiped] =
      LocalInboxNativeSurface.build(snapshot(), selected_state: :gossiped_ref).rows

    gossip_surface =
      LocalInboxNativeSurface.build(snapshot(), detail_message_key: gossiped.message_key)

    assert gossip_surface.detail.observed_via == [:gossip_simulation]
    assert "Observed via: gossip_simulation" in gossip_surface.detail.detail_lines
    assert gossip_surface.detail.limitation =~ "not guaranteed delivery"
  end

  test "missing detail selection is explicit" do
    surface = LocalInboxNativeSurface.build(snapshot(), detail_message_key: "missing")

    assert surface.detail == %{status: :not_found, title: "Message not found"}
  end

  test "empty selected state uses state-specific copy" do
    surface =
      LocalInboxNativeSurface.build(%{nearby_messages: []},
        selected_state: :unresolved_ref
      )

    assert surface.empty?
    assert surface.summary_line == "0 nearby | full 0 | refs 0 | gossip 0 | stale 0"
    assert surface.empty_label == "No unresolved beacon refs."
  end
end
