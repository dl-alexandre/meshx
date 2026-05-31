defmodule Mob.Node.BLE.LocalSecurityReplayLifecyclePolicy do
  @moduledoc """
  Replay lifecycle policy for local BLE security proofs.

  The current replay guard is intentionally in-memory. This policy records
  that restart-surviving replay state is not implemented and that replay
  evidence is limited to bounded foreground/session validation. It does not
  persist replay state, write storage, verify signatures, fetch, route, ACK,
  retry, encrypt, or run background work.
  """

  @blocked_claims [
    :durable_replay_state,
    :restart_surviving_replay_protection,
    :trusted_delivery,
    :guaranteed_delivery,
    :background_operation
  ]

  @spec snapshot() :: map()
  def snapshot do
    %{
      policy_version: 1,
      boundary: :memory_only_replay_lifecycle_policy,
      replay_state_mode: :memory_only,
      restart_behavior: :cleared_on_process_restart,
      durable_replay_state_allowed?: false,
      restart_surviving_replay_protection_claim_allowed?: false,
      trusted_delivery_claim_allowed?: false,
      background_replay_claim_allowed?: false,
      blocked_claims: @blocked_claims,
      required_before_durable: [
        :durable_replay_store_policy,
        :schema_versioning,
        :bounded_pruning,
        :restart_restore_fixture,
        :corruption_fail_closed_fixture,
        :release_artifact_evidence
      ],
      notes: [
        "Replay protection is bounded to supplied in-memory state.",
        "A new process/session starts with empty replay state unless a future durable policy is implemented.",
        "Replay lifecycle evidence is freshness/duplicate evidence only; it is not delivery proof."
      ]
    }
  end

  @spec json_snapshot() :: map()
  def json_snapshot do
    snapshot()
    |> JSON.encode!()
    |> JSON.decode!()
  end
end
