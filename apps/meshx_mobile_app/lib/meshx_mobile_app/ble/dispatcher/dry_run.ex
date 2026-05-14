defmodule MeshxMobileApp.BLE.Dispatcher.DryRun do
  @moduledoc """
  Dry-run dispatcher — accepts a list of `Attempt` records and produces
  one `AttemptOutcome` per attempt without doing anything else.

  ## Outcome rules

    * Attempt fails basic validation → `:invalid_attempt` with a
      `:validation` reason.
    * Caller-supplied `:skip?` predicate returns true → `:skipped`
      with a `:skip_predicate` reason.
    * Otherwise → `:would_dispatch`.

  ## What this is not

  No connections, no logs, no side effects. Pure function from
  `(attempts, opts)` to `[outcome]`. Same inputs always produce the
  same output.
  """

  alias MeshxMobileApp.BLE.AttemptLedger.Attempt
  alias MeshxMobileApp.BLE.AttemptOutcome

  @type opts :: [
          outcome_at: integer(),
          skip?: (Attempt.t() -> boolean())
        ]

  @adapter :dry_run

  @spec dispatch([Attempt.t()], opts()) :: [AttemptOutcome.t()]
  def dispatch(attempts, opts) when is_list(attempts) do
    outcome_at = Keyword.fetch!(opts, :outcome_at)
    skip? = Keyword.get(opts, :skip?, fn _ -> false end)

    Enum.map(attempts, fn %Attempt{} = a ->
      cond do
        not valid?(a) -> outcome(a, :invalid_attempt, :validation, outcome_at)
        skip?.(a) -> outcome(a, :skipped, :skip_predicate, outcome_at)
        true -> outcome(a, :would_dispatch, nil, outcome_at)
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
