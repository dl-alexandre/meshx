defmodule Mob.Node.BLE.AttemptLedger do
  @moduledoc """
  Pure conversion of `MessagePlanner` decisions into auditable
  attempt-intent records.

  An "attempt" is the intent to deliver one envelope to one target
  peer. The ledger never sends, never retries, never opens a
  connection — it just records what *would* be attempted, with
  enough provenance (the planner's eligibility snapshot at planning
  time) to explain the decision later.

  ## Inputs

      MessagePlanner.plan(...) :: {:eligible, plan} | {:ineligible, reason}

  Plus opts:

    * `:planned_at` (required) — integer in the caller's chosen
      scale. The clock is always an input; this module never reads
      a clock itself.
    * `:id_fun` (optional) — a 1-arity function from `attempt_index :: non_neg_integer()`
      to a binary `attempt_id`. Tests inject a deterministic counter;
      production calls default to a random 16-hex-char ID derived
      from `crypto.strong_rand_bytes/1`.

  ## Outputs

      {:ok, [%Attempt{status: :planned, …}, …]}
      {:error, reason}

  Directed plans produce exactly one attempt. Broadcast plans
  produce one attempt per candidate, in the same order
  `MessagePlanner` returned (last_seen desc, display_name asc).
  `:ineligible` plans surface the planner's reason verbatim.

  ## What this is not

  No queue. No retry. No persistence. No background ticking. No
  send. The output is a list of immutable structs the caller can
  inspect, log, or hand to a future transport dispatcher.
  """

  alias Mob.Node.BLE.MessagePlanner
  alias Mob.Node.BLE.MessagePlanner.{BroadcastPlan, DirectedPlan}
  alias Mob.Node.BLE.PeerInventory.PeerSummary

  defmodule Attempt do
    @moduledoc """
    One immutable record describing the intent to deliver an
    envelope to a specific target peer. `status` is always
    `:planned` in M16 — later milestones extend the lifecycle.
    """

    @type plan_type :: :directed | :broadcast
    @type status :: :planned

    @type t :: %__MODULE__{
            attempt_id: binary(),
            message_id: binary(),
            plan_type: plan_type(),
            target_peer_id: binary(),
            target_device_ids: [binary()],
            eligibility_snapshot: PeerSummary.t(),
            planned_at: integer(),
            status: status()
          }

    @enforce_keys [
      :attempt_id,
      :message_id,
      :plan_type,
      :target_peer_id,
      :target_device_ids,
      :eligibility_snapshot,
      :planned_at
    ]
    defstruct [
      :attempt_id,
      :message_id,
      :plan_type,
      :target_peer_id,
      :target_device_ids,
      :eligibility_snapshot,
      :planned_at,
      status: :planned
    ]
  end

  @type opts :: [
          planned_at: integer(),
          id_fun: (non_neg_integer() -> binary())
        ]

  @type planner_outcome ::
          {:eligible, MessagePlanner.plan()} | {:ineligible, MessagePlanner.reason()}

  @doc """
  Turns a planner outcome into a list of attempt intents.

  Returns `{:ok, [Attempt]}` for eligible plans, `{:error, reason}`
  for ineligible ones (the planner's reason is surfaced verbatim).
  Pure: same inputs always produce the same output (given a
  deterministic `:id_fun`).
  """
  @spec record(planner_outcome(), opts()) ::
          {:ok, [Attempt.t()]} | {:error, MessagePlanner.reason()}
  def record(planner_outcome, opts) do
    planned_at = Keyword.fetch!(opts, :planned_at)
    id_fun = Keyword.get(opts, :id_fun, &default_id/1)

    case planner_outcome do
      {:eligible, %DirectedPlan{} = plan} ->
        {:ok, [build_attempt(plan, plan.recipient, 0, planned_at, id_fun)]}

      {:eligible, %BroadcastPlan{} = plan} ->
        attempts =
          plan.candidates
          |> Enum.with_index()
          |> Enum.map(fn {candidate, index} ->
            build_attempt(plan, candidate, index, planned_at, id_fun)
          end)

        {:ok, attempts}

      {:ineligible, reason} ->
        {:error, reason}
    end
  end

  defp build_attempt(plan, %PeerSummary{} = peer, index, planned_at, id_fun) do
    %Attempt{
      attempt_id: id_fun.(index),
      message_id: plan.envelope.message_id,
      plan_type: plan_type_for(plan),
      target_peer_id: peer.peer_id,
      target_device_ids: peer.device_ids,
      eligibility_snapshot: peer,
      planned_at: planned_at,
      status: :planned
    }
  end

  defp plan_type_for(%DirectedPlan{}), do: :directed
  defp plan_type_for(%BroadcastPlan{}), do: :broadcast

  # 16-hex-char ID derived from 8 random bytes. Tests inject their
  # own deterministic id_fun.
  defp default_id(_index), do: Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)
end
