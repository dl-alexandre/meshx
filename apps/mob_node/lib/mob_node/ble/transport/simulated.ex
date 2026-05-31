defmodule Mob.Node.BLE.Transport.Simulated do
  @moduledoc """
  In-memory fake transport for offline integration tests.

  Accepts `Attempt` records the same way a real BLE transport would
  and produces `AttemptOutcome`s describing what the simulated wire
  would have done.

  ## Configuration

  `opts`:

    * `:outcome_at` (required) — integer, same scale as the rest of
      the pipeline. Stamped on every produced outcome.
    * `:transport_unavailable` (default `false`) — when `true`, every
      attempt fails with reason `:transport_unavailable`. Simulates
      Bluetooth off, adapter missing, or scan budget exhausted.
    * `:peer_failures` (default `%{}`) — `%{peer_id => reason}`. Any
      attempt targeting one of these peers becomes
      `:failed_simulated` with that reason. Simulates a peer that's
      reachable in the inventory but rejects the actual write.
    * `:skip?` — predicate `(Attempt -> boolean)` matching
      `Dispatcher.DryRun`. Same semantics.

  ## Outcome rules (in priority order)

    1. `transport_unavailable: true` → every attempt is
       `:failed_simulated` / `:transport_unavailable`. No further
       checks run.
    2. Attempt fails validation → `:invalid_attempt` / `:validation`.
    3. `:skip?` predicate matches → `:skipped` / `:skip_predicate`.
    4. Target peer is in `:peer_failures` → `:failed_simulated` with
       the supplied reason.
    5. Otherwise → `:delivered_simulated`, `reason: nil`.

  ## What this is not

  No actual BLE transmission. No queue, no retry, no persistence,
  no background work. Pure function — given the same opts and
  attempts, produces byte-identical outcomes.
  """

  alias Mob.Node.BLE.AttemptLedger.Attempt
  alias Mob.Node.BLE.AttemptOutcome

  @type opts :: [
          outcome_at: integer(),
          transport_unavailable: boolean(),
          peer_failures: %{optional(binary()) => term()},
          skip?: (Attempt.t() -> boolean())
        ]

  @adapter :simulated

  @spec dispatch([Attempt.t()], opts()) :: [AttemptOutcome.t()]
  def dispatch(attempts, opts) when is_list(attempts) do
    outcome_at = Keyword.fetch!(opts, :outcome_at)
    unavailable? = Keyword.get(opts, :transport_unavailable, false)
    peer_failures = Keyword.get(opts, :peer_failures, %{})
    skip? = Keyword.get(opts, :skip?, fn _ -> false end)

    Enum.map(attempts, fn %Attempt{} = a ->
      cond do
        unavailable? ->
          outcome(a, :failed_simulated, :transport_unavailable, outcome_at)

        not valid?(a) ->
          outcome(a, :invalid_attempt, :validation, outcome_at)

        skip?.(a) ->
          outcome(a, :skipped, :skip_predicate, outcome_at)

        Map.has_key?(peer_failures, a.target_peer_id) ->
          outcome(a, :failed_simulated, Map.fetch!(peer_failures, a.target_peer_id), outcome_at)

        true ->
          outcome(a, :delivered_simulated, nil, outcome_at)
      end
    end)
  end

  defp valid?(%Attempt{} = a) do
    is_binary(a.attempt_id) and byte_size(a.attempt_id) > 0 and
      is_binary(a.message_id) and byte_size(a.message_id) > 0 and
      is_binary(a.target_peer_id) and byte_size(a.target_peer_id) > 0 and
      is_list(a.target_device_ids) and a.target_device_ids != []
  end

  defp outcome(%Attempt{} = a, kind, reason, outcome_at) do
    %AttemptOutcome{
      attempt_id: a.attempt_id,
      message_id: a.message_id,
      target_peer_id: a.target_peer_id,
      target_device_ids: a.target_device_ids,
      kind: kind,
      outcome_at: outcome_at,
      reason: reason,
      adapter: @adapter
    }
  end
end
