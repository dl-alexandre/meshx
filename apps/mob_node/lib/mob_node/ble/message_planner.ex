defmodule Mob.Node.BLE.MessagePlanner do
  @moduledoc """
  Pure-data eligibility planner over `MessageEnvelope` + `PeerInventory`.

  Answers a single question: *should this envelope be attempted right
  now, against this inventory?* The planner never opens a connection,
  never queues, never sends — it just produces a decision and, when
  the answer is yes, the shape of what would be attempted.

  ## Outcomes

      {:eligible, %DirectedPlan{envelope: …, recipient: %PeerSummary{}}}
      {:eligible, %BroadcastPlan{envelope: …, candidates: [%PeerSummary{}, …]}}
      {:ineligible, reason}

  Both plan structs reference the same `PeerSummary` shape callers
  already get from `PeerInventory`. Nothing in the planner output
  depends on `PeerTable` internals.

  ## Eligibility rules

  Per-envelope:

    * `ttl > 0` (a forwarder shouldn't accept an exhausted envelope).
    * `payload` already fits the size bound (defensive — should
      already hold for any envelope from `MessageEnvelope.build/1`).

  Directed (`recipient_peer_id != nil`):

    * a `PeerSummary` exists with matching `peer_id`,
    * the matched peer is `:active`,
    * the peer's capabilities cover `envelope.capability_requirements`,
    * the peer's `identity_confidence` is `:advertised` or `:verified`
      (rejected on `:unknown` or `:contested` unless the caller passes
      `allow_low_confidence: true`).

  Broadcast (`recipient_peer_id == nil`):

    * filter the inventory by the same active + capability +
      confidence criteria,
    * at least one peer must survive the filter,
    * the surviving list is returned in `BroadcastPlan.candidates`,
      sorted deterministically by `last_seen_at` desc with
      `display_name` asc as the tiebreaker (matches
      `PeerInventory.list/2`).

  ## Now injection

  The planner re-derives presence using the caller-supplied `:now` so
  eligibility is computed at an explicit moment. Whatever `presence`
  field the input summaries carry is ignored. Consistent with
  `Mob.Node.BLE.PresencePolicy` — the clock is always an input,
  never a side effect.

  ## What this is not

  No connections. No routing. No queue. No retry. No persistence. No
  crypto. The planner is pure — `plan(envelope, summaries, opts)`
  always returns the same answer for the same inputs.
  """

  alias Mob.Node.BLE.{MessageEnvelope, PeerCapabilities, PeerInventory, PresencePolicy}
  alias Mob.Node.BLE.PeerInventory.PeerSummary

  defmodule DirectedPlan do
    @moduledoc false

    @type t :: %__MODULE__{
            envelope: MessageEnvelope.t(),
            recipient: PeerSummary.t()
          }

    @enforce_keys [:envelope, :recipient]
    defstruct [:envelope, :recipient]
  end

  defmodule BroadcastPlan do
    @moduledoc false

    @type t :: %__MODULE__{
            envelope: MessageEnvelope.t(),
            candidates: [PeerSummary.t()]
          }

    @enforce_keys [:envelope, :candidates]
    defstruct [:envelope, :candidates]
  end

  @type plan :: DirectedPlan.t() | BroadcastPlan.t()

  @type reason ::
          :ttl_exhausted
          | :payload_too_large
          | :recipient_unknown
          | :recipient_inactive
          | :capability_mismatch
          | :insufficient_identity_confidence
          | :no_eligible_broadcast_peers

  @type opts :: [
          now: integer(),
          policy: PresencePolicy.t(),
          allow_low_confidence: boolean()
        ]

  @doc """
  Plans an envelope against an inventory snapshot at the given `now`.

  Required opts:

    * `:now` — integer in the same scale as `PeerSummary.last_seen_at`.

  Optional opts:

    * `:policy` — `PresencePolicy.t()`. Defaults to
      `PresencePolicy.default/0`.
    * `:allow_low_confidence` — when `true`, peers with `:unknown` or
      `:contested` identity confidence are eligible. Defaults to `false`.
  """
  @spec plan(MessageEnvelope.t(), [PeerSummary.t()], opts()) ::
          {:eligible, plan()} | {:ineligible, reason()}
  def plan(%MessageEnvelope{} = envelope, summaries, opts) when is_list(summaries) do
    now = Keyword.fetch!(opts, :now)
    policy = Keyword.get(opts, :policy, PresencePolicy.default())
    allow_low_confidence = Keyword.get(opts, :allow_low_confidence, false)

    fresh = PeerInventory.with_presence(summaries, now: now, policy: policy)

    with :ok <- check_envelope(envelope) do
      case envelope.recipient_peer_id do
        nil -> plan_broadcast(envelope, fresh, allow_low_confidence)
        recipient -> plan_directed(envelope, fresh, recipient, allow_low_confidence)
      end
    end
  end

  # ── envelope-level checks ──────────────────────────────────────────────────

  defp check_envelope(%MessageEnvelope{ttl: 0}), do: {:ineligible, :ttl_exhausted}

  defp check_envelope(%MessageEnvelope{payload: payload}) do
    if byte_size(payload) > MessageEnvelope.max_payload_size() do
      {:ineligible, :payload_too_large}
    else
      :ok
    end
  end

  # ── directed ───────────────────────────────────────────────────────────────

  defp plan_directed(envelope, summaries, recipient_peer_id, allow_low_confidence) do
    with {:ok, match} <- find_recipient(summaries, recipient_peer_id),
         :ok <- check_active(match),
         :ok <- check_capabilities(match, envelope),
         :ok <- check_confidence(match, allow_low_confidence) do
      {:eligible, %DirectedPlan{envelope: envelope, recipient: match}}
    end
  end

  defp find_recipient(summaries, recipient_peer_id) do
    case Enum.find(summaries, &(&1.peer_id == recipient_peer_id)) do
      nil -> {:ineligible, :recipient_unknown}
      %PeerSummary{} = match -> {:ok, match}
    end
  end

  defp check_active(%PeerSummary{presence: :active}), do: :ok
  defp check_active(%PeerSummary{}), do: {:ineligible, :recipient_inactive}

  defp check_capabilities(%PeerSummary{capabilities: caps}, %MessageEnvelope{
         capability_requirements: req
       }) do
    if PeerCapabilities.satisfies?(caps, req) do
      :ok
    else
      {:ineligible, :capability_mismatch}
    end
  end

  defp check_confidence(%PeerSummary{identity_confidence: c}, _allow)
       when c in [:advertised, :verified],
       do: :ok

  defp check_confidence(%PeerSummary{}, true), do: :ok

  defp check_confidence(%PeerSummary{}, false),
    do: {:ineligible, :insufficient_identity_confidence}

  # ── broadcast ──────────────────────────────────────────────────────────────

  defp plan_broadcast(envelope, summaries, allow_low_confidence) do
    candidates =
      summaries
      |> Enum.filter(&(&1.presence == :active))
      |> Enum.filter(&peer_caps_satisfy?(&1, envelope))
      |> Enum.filter(&peer_confidence_ok?(&1, allow_low_confidence))
      |> Enum.sort_by(fn s -> {-s.last_seen_at, s.display_name} end)

    case candidates do
      [] -> {:ineligible, :no_eligible_broadcast_peers}
      _ -> {:eligible, %BroadcastPlan{envelope: envelope, candidates: candidates}}
    end
  end

  defp peer_caps_satisfy?(%PeerSummary{capabilities: caps}, %MessageEnvelope{
         capability_requirements: req
       }) do
    PeerCapabilities.satisfies?(caps, req)
  end

  defp peer_confidence_ok?(%PeerSummary{identity_confidence: c}, _allow)
       when c in [:advertised, :verified],
       do: true

  defp peer_confidence_ok?(%PeerSummary{}, true), do: true
  defp peer_confidence_ok?(%PeerSummary{}, false), do: false
end
