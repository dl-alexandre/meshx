defmodule MeshxMobileApp.BLE.Dispatcher.Android do
  @moduledoc """
  Real-transport dispatcher for the Android BLE bridge.

  Conforms to the same `[Attempt] → [AttemptOutcome]` shape as
  `Dispatcher.DryRun` and `Transport.Simulated`. Distinguished only
  by the outcomes it can produce:

    * `:dispatched` — the local Android BLE stack accepted the send
      via the bridge.
    * `:failed` — the local Android BLE stack rejected the send. The
      caller-supplied reason rides in `outcome.reason`.
    * `:skipped` — caller-supplied `:skip?` predicate matched.
    * `:invalid_attempt` — attempt failed dispatcher validation.
    * `:would_dispatch` — only when `:dry_run` is `true` in opts. Lets
      a caller verify routing without actually invoking the radio.

  Notably **does not** produce `:delivered_simulated` or
  `:failed_simulated` — those are reserved for `Transport.Simulated`
  and the closed taxonomy keeps the two layers distinguishable.

  ## Native bridge

  The actual send happens through an injectable function:

      :native_send (Attempt.t() -> {:ok, term()} | {:error, term()})

  In production, this points at the Kotlin `BleDispatcher` via the
  future BEAM-on-Android NIF. For tests, the caller passes a fake.

  When `:native_send` is omitted, the default returns
  `{:error, :native_bridge_unavailable}` — surfaces as `:failed` with
  that reason. This is the correct behavior on every Elixir runtime
  that doesn't have the Android bridge wired up (i.e. host tests,
  iOS device, server-side IEx).

  ## What this is not

  No connection management. No retry. No queue. No persistence. The
  dispatcher is one synchronous pass over the attempts; consequences
  for the next pass are the caller's concern.
  """

  alias MeshxMobileApp.BLE.AttemptLedger.Attempt
  alias MeshxMobileApp.BLE.AttemptOutcome

  @type opts :: [
          outcome_at: integer(),
          native_send: (Attempt.t() -> {:ok, term()} | {:error, term()}),
          skip?: (Attempt.t() -> boolean()),
          dry_run: boolean()
        ]

  @adapter :ble_android

  @spec dispatch([Attempt.t()], opts()) :: [AttemptOutcome.t()]
  def dispatch(attempts, opts) when is_list(attempts) do
    outcome_at = Keyword.fetch!(opts, :outcome_at)
    native_send = Keyword.get(opts, :native_send, &default_native_send/1)
    skip? = Keyword.get(opts, :skip?, fn _ -> false end)
    dry_run? = Keyword.get(opts, :dry_run, false)

    Enum.map(attempts, fn %Attempt{} = a ->
      cond do
        not valid?(a) ->
          outcome(a, :invalid_attempt, :validation, outcome_at)

        skip?.(a) ->
          outcome(a, :skipped, :skip_predicate, outcome_at)

        dry_run? ->
          outcome(a, :would_dispatch, nil, outcome_at)

        true ->
          case native_send.(a) do
            {:ok, _info} -> outcome(a, :dispatched, nil, outcome_at)
            {:error, reason} -> outcome(a, :failed, reason, outcome_at)
          end
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

  # Default when no bridge is injected. This is the truthful answer on
  # every runtime that doesn't have the Android NIF loaded — including
  # host ExUnit, iOS device, and any future server-side Elixir.
  defp default_native_send(_attempt), do: {:error, :native_bridge_unavailable}
end
