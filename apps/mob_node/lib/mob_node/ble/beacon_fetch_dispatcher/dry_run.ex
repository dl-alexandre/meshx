defmodule Mob.Node.BLE.BeaconFetchDispatcher.DryRun do
  @moduledoc """
  Dry-run dispatcher for legacy beacon fetch attempts.

  Produces auditable outcomes without opening a transport or changing
  state.
  """

  alias Mob.Node.BLE.BeaconFetchAttemptLedger.FetchAttempt

  defmodule Outcome do
    @moduledoc false

    @type kind :: :would_fetch | :skipped | :invalid_request | :no_candidates

    @enforce_keys [
      :fetch_attempt_id,
      :request_id,
      :message_id_hash,
      :target_peer_id,
      :target_device_ids,
      :kind,
      :outcome_at,
      :adapter
    ]
    defstruct @enforce_keys ++ [reason: nil]

    @type t :: %__MODULE__{
            fetch_attempt_id: binary() | nil,
            request_id: binary() | nil,
            message_id_hash: binary() | nil,
            target_peer_id: binary() | nil,
            target_device_ids: [binary()],
            kind: kind(),
            outcome_at: integer(),
            reason: atom() | nil,
            adapter: :fetch_dry_run
          }
  end

  @type opts :: [
          outcome_at: integer(),
          request_id: binary(),
          message_id_hash: binary(),
          skip?: (FetchAttempt.t() -> boolean())
        ]

  @adapter :fetch_dry_run

  @spec dispatch([FetchAttempt.t()], opts()) :: [Outcome.t()]
  def dispatch([], opts) do
    outcome_at = Keyword.fetch!(opts, :outcome_at)

    [
      %Outcome{
        fetch_attempt_id: nil,
        request_id: Keyword.get(opts, :request_id),
        message_id_hash: Keyword.get(opts, :message_id_hash),
        target_peer_id: nil,
        target_device_ids: [],
        kind: :no_candidates,
        outcome_at: outcome_at,
        reason: :empty_candidates,
        adapter: @adapter
      }
    ]
  end

  def dispatch(attempts, opts) when is_list(attempts) do
    outcome_at = Keyword.fetch!(opts, :outcome_at)
    skip? = Keyword.get(opts, :skip?, fn _ -> false end)

    Enum.map(attempts, fn
      %FetchAttempt{} = attempt ->
        cond do
          not valid?(attempt) -> outcome(attempt, :invalid_request, :validation, outcome_at)
          skip?.(attempt) -> outcome(attempt, :skipped, :skip_predicate, outcome_at)
          true -> outcome(attempt, :would_fetch, nil, outcome_at)
        end
    end)
  end

  defp valid?(%FetchAttempt{} = attempt) do
    is_binary(attempt.fetch_attempt_id) and attempt.fetch_attempt_id != "" and
      is_binary(attempt.request_id) and attempt.request_id != "" and
      is_binary(attempt.message_id_hash) and byte_size(attempt.message_id_hash) == 8 and
      is_binary(attempt.target_peer_id) and attempt.target_peer_id != "" and
      is_list(attempt.target_device_ids) and attempt.target_device_ids != []
  end

  defp outcome(%FetchAttempt{} = attempt, kind, reason, outcome_at) do
    %Outcome{
      fetch_attempt_id: attempt.fetch_attempt_id,
      request_id: attempt.request_id,
      message_id_hash: attempt.message_id_hash,
      target_peer_id: attempt.target_peer_id,
      target_device_ids: attempt.target_device_ids,
      kind: kind,
      outcome_at: outcome_at,
      reason: reason,
      adapter: @adapter
    }
  end
end
