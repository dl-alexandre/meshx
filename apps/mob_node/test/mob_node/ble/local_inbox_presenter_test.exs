defmodule Mob.Node.BLE.LocalInboxPresenterTest do
  use ExUnit.Case, async: true

  alias Mob.Node.BLE.{LocalInboxPresenter, LocalInboxView}

  test "renders empty nearby message state" do
    assert LocalInboxPresenter.render_text(nil) == "No nearby messages"
    assert LocalInboxPresenter.render_text(%{nearby_messages: []}) == "No nearby messages"
  end

  test "renders counts, resolution blockers, trust, and item details" do
    full = item(:full_message, message_key: "full-key", message_id: <<1::128>>, last_seen_at: 20)

    ref =
      item(:unresolved_ref, message_key: "ref-key", message_id_hash: <<2::64>>, last_seen_at: 10)

    text =
      LocalInboxPresenter.render_text(%{
        nearby_messages: [full, ref],
        resolution_statuses: [
          %{
            message_key: "full-key",
            resolution_state: :full_envelope_present,
            fetch_transport_state: :not_needed
          },
          %{
            message_key: "ref-key",
            resolution_state: :needs_fetch,
            fetch_transport_state: :not_validated
          }
        ],
        trust_evidence: [
          %{message_key: "full-key", trust_state: :unsigned_observation},
          %{message_key: "ref-key", trust_state: :untrusted_reference}
        ]
      })

    assert text =~ "Nearby Messages"
    assert text =~ "Full 1 | Unresolved refs 1 | Gossiped refs 0 | Stale refs 0"
    assert text =~ "Resolution full 1 | known 0 | needs fetch 1 | stale fetch 0 | unresolvable 0"
    assert text =~ "Blocked: fetch_transport_not_validated"
    assert text =~ "Full messages - Validated full MessageEnvelope adverts."
    assert text =~ "Unresolved refs - Legacy beacon refs that need a future fetch transport."

    assert text =~
             "full 000000000000 kind=TX resolve=full_envelope_present fetch=not_needed trust=unsigned_observation"

    assert text =~
             "unresolved-ref 000000000000 kind=TX resolve=needs_fetch fetch=not_validated trust=untrusted_reference"
  end

  test "renders gossiped and stale refs distinctly" do
    gossip =
      item(:gossiped_ref,
        message_key: "gossip-key",
        message_id_hash: <<3::64>>,
        observed_via: [:gossip_simulation],
        last_seen_at: 30
      )

    stale =
      item(:stale_ref,
        message_key: "stale-key",
        message_id_hash: <<4::64>>,
        last_seen_at: 1
      )

    text = LocalInboxPresenter.render_text(%{nearby_messages: [gossip, stale]})

    assert text =~ "Full 0 | Unresolved refs 0 | Gossiped refs 1 | Stale refs 1"
    assert text =~ "gossiped-ref"
    assert text =~ "stale-ref"
  end

  test "renders selected detail copy with state-specific limitations" do
    ref =
      item(:gossiped_ref,
        message_key: "gossip-key",
        message_id_hash: <<3::64>>,
        observed_via: [:gossip_simulation],
        last_seen_at: 30
      )

    text =
      LocalInboxPresenter.render_text(
        %{nearby_messages: [ref]},
        detail_message_key: "gossip-key"
      )

    assert text =~ "Selected: Gossiped beacon ref"
    assert text =~ "state=gossiped_ref badge=gossip severity=informational"
    assert text =~ "limit=Advert gossip observation is not guaranteed delivery."
    assert text =~ "next=Keep as nearby gossip evidence only."

    assert text =~
             "blocked=not guaranteed delivery; not authenticated authorship; not multi-hop hardware proof; not routed delivery"
  end

  defp item(state, opts) do
    %LocalInboxView.Item{
      state: state,
      message_key: Keyword.fetch!(opts, :message_key),
      message_id: Keyword.get(opts, :message_id),
      message_id_hash: Keyword.get(opts, :message_id_hash),
      sender_peer_id: "peer-a",
      sender_peer_hash: <<9::64>>,
      payload_kind: "TX",
      first_seen_at: Keyword.get(opts, :first_seen_at, 1),
      last_seen_at: Keyword.get(opts, :last_seen_at, 1),
      seen_count: Keyword.get(opts, :seen_count, 1),
      source_device_ids: Keyword.get(opts, :source_device_ids, ["device-a"]),
      last_rssi: Keyword.get(opts, :last_rssi, -60),
      observed_via: Keyword.get(opts, :observed_via, [])
    }
  end
end
