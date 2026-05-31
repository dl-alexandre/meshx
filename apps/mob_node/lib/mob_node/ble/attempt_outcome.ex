defmodule Mob.Node.BLE.AttemptOutcome do
  @moduledoc """
  Immutable outcome record for one `Mob.Node.BLE.AttemptLedger.Attempt`.

  Produced by dispatch modules (`Mob.Node.BLE.Dispatcher.DryRun`,
  `Mob.Node.BLE.Transport.Simulated`, and future real-transport
  adapters). Carries enough provenance — `attempt_id`, `message_id`,
  `target_peer_id`, `target_device_ids` — that a consumer can correlate
  outcomes back to the planning trail without inspecting any other
  state.

  ## Closed `kind` taxonomy

    * `:planned` — fresh attempt that hasn't reached a dispatcher yet.
      Equivalent to `Attempt.status` of the same name; included here so
      consumers can hold a uniform list of outcomes for an envelope.
    * `:would_dispatch` — dry-run only; the dispatcher accepted the
      attempt and would have sent it.
    * `:delivered_simulated` — simulated transport reported success.
    * `:failed_simulated` — simulated transport reported failure (the
      `reason` field carries detail).
    * `:dispatched` — **real** transport accepted the attempt. The local
      BLE stack acknowledged the send; that's all we claim. Peer
      reception is not implied — there's no return-path yet.
    * `:failed` — **real** transport rejected the attempt. Distinct
      from `:failed_simulated` so consumers can tell the difference
      between "the fake said no" and "the radio said no".
    * `:skipped` — dispatcher policy chose not to attempt (e.g., a
      caller-supplied skip predicate).
    * `:invalid_attempt` — the attempt itself failed dispatcher-side
      validation (missing fields, malformed identifiers, etc.).

  ## `adapter` taxonomy

  Closed atom set so consumers can route on it:

    * `:dry_run` — produced by `Dispatcher.DryRun`.
    * `:simulated` — produced by `Transport.Simulated`.
    * Future: `:ble_android`, `:ble_ios`, …
  """

  @type kind ::
          :planned
          | :would_dispatch
          | :delivered_simulated
          | :failed_simulated
          | :dispatched
          | :failed
          | :skipped
          | :invalid_attempt

  @type adapter :: :dry_run | :simulated | :ble_android | :ble_ios

  @type t :: %__MODULE__{
          attempt_id: binary(),
          message_id: binary(),
          target_peer_id: binary() | nil,
          target_device_ids: [binary()],
          kind: kind(),
          outcome_at: integer(),
          reason: term() | nil,
          adapter: adapter()
        }

  @enforce_keys [
    :attempt_id,
    :message_id,
    :target_peer_id,
    :target_device_ids,
    :kind,
    :outcome_at,
    :adapter
  ]
  defstruct [
    :attempt_id,
    :message_id,
    :target_peer_id,
    :target_device_ids,
    :kind,
    :outcome_at,
    :reason,
    :adapter
  ]
end
