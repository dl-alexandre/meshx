defmodule Mob.Node.BLE.AdvertGossipDispatcher.Android do
  @moduledoc """
  Android execution adapter for advertisement gossip intents.

  Only `:legacy_beacon_advert` is enabled by default. Full-envelope
  advertisement gossip is skipped unless the caller explicitly marks the
  path capability-proven. The native bridge is injected so host tests
  never touch BLE.

  No GATT, routing, persistence, ACK, retry, crypto, fragmentation, or
  background service behavior is introduced here.
  """

  alias Mob.Node.BLE.AdvertGossipPlanner.Intent
  alias Mob.Node.BLE.Events.AdvertGossipOutcome

  @adapter :ble_android

  @type opts :: [
          outcome_at: integer(),
          native_send: (Intent.t() -> {:ok, term()} | {:error, term()}),
          dry_run: boolean(),
          full_envelope_capability_proven: boolean()
        ]

  @spec dispatch([Intent.t()], opts()) :: [AdvertGossipOutcome.t()]
  def dispatch(intents, opts) when is_list(intents) do
    outcome_at = Keyword.fetch!(opts, :outcome_at)
    native_send = Keyword.get(opts, :native_send, &default_native_send/1)
    dry_run? = Keyword.get(opts, :dry_run, false)
    full_envelope_capability_proven = Keyword.get(opts, :full_envelope_capability_proven, false)

    Enum.map(intents, fn
      %Intent{} = intent ->
        cond do
          not valid?(intent) ->
            outcome(intent, :invalid_intent, :validation, outcome_at)

          dry_run? ->
            outcome(intent, :would_gossip, nil, outcome_at)

          intent.advertise_as == :full_envelope_advert and not full_envelope_capability_proven ->
            outcome(intent, :skipped, :full_envelope_gossip_unproven, outcome_at)

          intent.advertise_as == :full_envelope_advert ->
            outcome(intent, :skipped, :full_envelope_gossip_disabled, outcome_at)

          true ->
            case native_send.(intent) do
              {:ok, _info} -> outcome(intent, :gossiped, nil, outcome_at)
              {:error, reason} -> outcome(intent, :failed, reason, outcome_at)
            end
        end
    end)
  end

  defp valid?(%Intent{} = intent) do
    is_binary(intent.gossip_intent_id) and intent.gossip_intent_id != "" and
      intent.advertise_as in [:legacy_beacon_advert, :full_envelope_advert] and
      is_binary(intent.message_id_hash) and byte_size(intent.message_id_hash) == 8 and
      is_binary(intent.sender_peer_hash) and byte_size(intent.sender_peer_hash) == 8 and
      is_binary(intent.payload_kind) and intent.payload_kind != "" and
      is_integer(intent.envelope_version) and intent.envelope_version > 0
  end

  defp outcome(%Intent{} = intent, kind, reason, outcome_at) do
    %AdvertGossipOutcome{
      gossip_intent_id: intent.gossip_intent_id,
      message_id_hash: intent.message_id_hash,
      sender_peer_id_hash: intent.sender_peer_hash,
      advertise_as: intent.advertise_as,
      kind: kind,
      reason: reason,
      adapter: @adapter,
      outcome_at_ms: outcome_at
    }
  end

  defp default_native_send(_intent), do: {:error, :native_bridge_unavailable}
end
