defmodule Mob.Node.BLE.LocalInboxStateCopy do
  @moduledoc """
  Stable UI copy for advertisement-only local inbox states.

  This keeps state labels, badges, summaries, limitations, and next-action
  wording in one place so native surfaces do not drift into delivery,
  trust, routing, or fetch claims. It is pure presentation data and does
  not resolve beacon refs, fetch envelopes, route, persist, ACK, retry,
  encrypt, scan, advertise, or run background work.
  """

  alias Mob.Node.BLE.LocalInboxView

  @type severity :: :ready | :needs_transport | :informational | :stale

  @type t :: %{
          state: LocalInboxView.Item.state(),
          label: binary(),
          short_label: binary(),
          badge: binary(),
          summary: binary(),
          empty_label: binary(),
          detail_title: binary(),
          limitation: binary(),
          next_action: binary(),
          severity: severity(),
          delivery_claim_allowed?: boolean(),
          blocked_claims: [binary()]
        }

  @spec for_state(LocalInboxView.Item.state()) :: map()
  def for_state(:full_message) do
    %{
      state: :full_message,
      label: "Full messages",
      short_label: "Full",
      badge: "full",
      summary: "Validated full MessageEnvelope adverts.",
      empty_label: "No full messages seen nearby.",
      detail_title: "Full MessageEnvelope",
      limitation: "Canonical full MessageEnvelope advert is present.",
      next_action: "Display from canonical envelope.",
      severity: :ready,
      delivery_claim_allowed?: false,
      blocked_claims: [
        "not a delivery receipt",
        "not authenticated authorship",
        "not routed delivery"
      ]
    }
  end

  def for_state(:unresolved_ref) do
    %{
      state: :unresolved_ref,
      label: "Unresolved refs",
      short_label: "Ref",
      badge: "ref",
      summary: "Legacy beacon refs that need a future fetch transport.",
      empty_label: "No unresolved beacon refs.",
      detail_title: "Unresolved beacon ref",
      limitation: "Legacy beacon ref is a pointer, not full message delivery.",
      next_action: "Wait for a validated fetch transport or matching full advert.",
      severity: :needs_transport,
      delivery_claim_allowed?: false,
      blocked_claims: [
        "not full message delivery",
        "not authenticated authorship",
        "not fetch success",
        "not routed delivery"
      ]
    }
  end

  def for_state(:gossiped_ref) do
    %{
      state: :gossiped_ref,
      label: "Gossiped refs",
      short_label: "Gossip",
      badge: "gossip",
      summary: "Beacon refs observed through advert gossip simulation or replay.",
      empty_label: "No gossiped refs.",
      detail_title: "Gossiped beacon ref",
      limitation: "Advert gossip observation is not guaranteed delivery.",
      next_action: "Keep as nearby gossip evidence only.",
      severity: :informational,
      delivery_claim_allowed?: false,
      blocked_claims: [
        "not guaranteed delivery",
        "not authenticated authorship",
        "not multi-hop hardware proof",
        "not routed delivery"
      ]
    }
  end

  def for_state(:stale_ref) do
    %{
      state: :stale_ref,
      label: "Stale refs",
      short_label: "Stale",
      badge: "stale",
      summary: "Refs older than the current freshness policy.",
      empty_label: "No stale refs.",
      detail_title: "Stale beacon ref",
      limitation: "Stale beacon ref remains a pointer until a fetch transport is validated.",
      next_action: "Show only as old nearby evidence.",
      severity: :stale,
      delivery_claim_allowed?: false,
      blocked_claims: [
        "not current nearby presence",
        "not full message delivery",
        "not authenticated authorship",
        "not routed delivery"
      ]
    }
  end

  @spec all() :: [map()]
  def all do
    [
      for_state(:full_message),
      for_state(:unresolved_ref),
      for_state(:gossiped_ref),
      for_state(:stale_ref)
    ]
  end

  @spec json_snapshot() :: map()
  def json_snapshot do
    %{state_copy_version: 1, states: all()}
    |> JSON.encode!()
    |> JSON.decode!()
  end
end
