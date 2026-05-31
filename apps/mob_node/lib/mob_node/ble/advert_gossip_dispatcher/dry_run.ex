defmodule Mob.Node.BLE.AdvertGossipDispatcher.DryRun do
  @moduledoc """
  Dry-run dispatcher for advertisement gossip intents.

  Produces auditable outcomes without opening BLE, advertising,
  persisting, retrying, ACKing, routing, or encrypting.
  """

  alias Mob.Node.BLE.AdvertGossipPlanner.Intent

  defmodule Outcome do
    @moduledoc false

    @enforce_keys [
      :gossip_intent_id,
      :message_id_hash,
      :sender_peer_hash,
      :kind,
      :outcome_at,
      :adapter
    ]
    defstruct @enforce_keys ++ [advertise_as: nil, reason: nil]

    @type kind :: :would_gossip | :invalid_intent | :no_candidates

    @type t :: %__MODULE__{
            gossip_intent_id: binary() | nil,
            message_id_hash: binary() | nil,
            sender_peer_hash: binary() | nil,
            advertise_as: atom() | nil,
            kind: kind(),
            outcome_at: integer(),
            reason: atom() | nil,
            adapter: :advert_gossip_dry_run
          }
  end

  @adapter :advert_gossip_dry_run

  @spec dispatch([Intent.t()], keyword()) :: [Outcome.t()]
  def dispatch([], opts) do
    outcome_at = Keyword.fetch!(opts, :outcome_at)

    [
      %Outcome{
        gossip_intent_id: nil,
        message_id_hash: nil,
        sender_peer_hash: nil,
        kind: :no_candidates,
        outcome_at: outcome_at,
        reason: :empty_intents,
        adapter: @adapter
      }
    ]
  end

  def dispatch(intents, opts) when is_list(intents) do
    outcome_at = Keyword.fetch!(opts, :outcome_at)

    Enum.map(intents, fn
      %Intent{} = intent ->
        if valid?(intent) do
          outcome(intent, :would_gossip, nil, outcome_at)
        else
          outcome(intent, :invalid_intent, :validation, outcome_at)
        end
    end)
  end

  defp valid?(%Intent{} = intent) do
    is_binary(intent.gossip_intent_id) and intent.gossip_intent_id != "" and
      is_binary(intent.message_id_hash) and byte_size(intent.message_id_hash) == 8 and
      is_binary(intent.sender_peer_hash) and byte_size(intent.sender_peer_hash) == 8 and
      intent.advertise_as in [:legacy_beacon_advert, :full_envelope_advert]
  end

  defp outcome(%Intent{} = intent, kind, reason, outcome_at) do
    %Outcome{
      gossip_intent_id: intent.gossip_intent_id,
      message_id_hash: intent.message_id_hash,
      sender_peer_hash: intent.sender_peer_hash,
      advertise_as: intent.advertise_as,
      kind: kind,
      outcome_at: outcome_at,
      reason: reason,
      adapter: @adapter
    }
  end
end
