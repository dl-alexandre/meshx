defmodule Mob.Node.BLE.LocalPersistenceProductionLifecyclePlan do
  @moduledoc """
  Production lifecycle plan for default local inbox persistence.

  Current persistence remains explicit opt-in durable read-model snapshots.
  This module records the gates that must pass before durable snapshots can
  become default app lifecycle behavior. It is planning data only: it does
  not migrate data, schedule cleanup, write in the background, restore on
  app start, persist raw evidence, resolve beacon refs, route, ACK, retry,
  encrypt, or authenticate messages.
  """

  defmodule Gate do
    @moduledoc false

    @derive {JSON.Encoder,
             only: [
               :id,
               :status,
               :required_evidence,
               :missing_evidence,
               :blocked_claims,
               :notes
             ]}
    @enforce_keys [
      :id,
      :status,
      :required_evidence,
      :missing_evidence,
      :blocked_claims,
      :notes
    ]
    defstruct @enforce_keys

    @type status :: :blocked

    @type t :: %__MODULE__{
            id: atom(),
            status: status(),
            required_evidence: [binary()],
            missing_evidence: [binary()],
            blocked_claims: [atom()],
            notes: [binary()]
          }
  end

  @spec gates() :: [Gate.t()]
  def gates do
    [
      gate(
        :default_lifecycle_decision,
        [
          "Product decision that durable local inbox snapshots should become default lifecycle behavior.",
          "Operator-facing release note preserving that snapshots are read models, not delivery records."
        ],
        [
          "Product approval for default durable local inbox lifecycle.",
          "Release wording that keeps delivery, routing, and trust claims blocked."
        ],
        [:delivery_record, :trusted_message_delivery],
        [
          "Default persistence must be an explicit product decision, not a side effect of opt-in storage."
        ]
      ),
      gate(
        :schema_migration_policy,
        [
          "Durable snapshot schema versioning policy for current-version restore.",
          "Forward migration, incompatible snapshot handling, and preserve-readable snapshot tests."
        ],
        [
          "Forward migration policy for future LocalInboxDurableSnapshot versions.",
          "Fixture tests for upgrade and incompatible snapshot cases before default persistence."
        ],
        [:unsafe_snapshot_upgrade, :silent_data_loss],
        [
          "Current schema policy restores JSON-decoded v1 snapshots and rejects unknown versions.",
          "Default persistence still needs forward schema evolution evidence before app restart restore is safe."
        ]
      ),
      gate(
        :scheduled_cleanup_worker,
        [
          "Bounded cleanup execution policy with injected clock.",
          "Evidence that expired snapshots are pruned without deleting unexpired snapshots."
        ],
        [
          "Scheduled cleanup worker or lifecycle hook.",
          "Injected-clock tests for expired and retained snapshot cleanup."
        ],
        [:unbounded_storage_growth, :background_persistence],
        [
          "Manual prune exists today; default lifecycle persistence needs automatic cleanup evidence."
        ]
      ),
      gate(
        :background_safe_writer,
        [
          "Mobile lifecycle-safe save policy for foreground/background transitions.",
          "Evidence that writes are bounded and do not imply background BLE operation."
        ],
        [
          "Background-safe write integration for app lifecycle transitions.",
          "Tests or device logs proving interrupted writes fail explicitly or restore safely."
        ],
        [:background_ble, :background_persistence],
        [
          "A writer may be lifecycle-safe without enabling background scanning, routing, or fetch."
        ]
      ),
      gate(
        :on_device_restore_fixture,
        [
          "On-device restart fixture restoring policy-approved nearby-message read models.",
          "Fixture evidence for full messages, unresolved refs, gossiped refs, and stale refs."
        ],
        [
          "Android or iOS app restart evidence showing restored LocalInbox read model state.",
          "Replay-normalized fixture tying restored rows back to canonical ingress."
        ],
        [:full_message_resolution, :delivery_record],
        [
          "Restored beacon refs must remain unresolved pointers unless a real fetch transport resolves them."
        ]
      ),
      gate(
        :release_artifact_evidence,
        [
          "Release manifest entries for lifecycle decision, migrations, cleanup, writer, and restore evidence.",
          "Operator review that blocked claims remain visible in release notes."
        ],
        [
          "Release-candidate artifact bundle containing default persistence lifecycle evidence.",
          "Operator review preserving default persistence limitations."
        ],
        [:release_overclaim, :trusted_message_delivery],
        [
          "Release evidence must be attached per release candidate before production wording changes."
        ]
      )
    ]
  end

  @spec snapshot() :: map()
  def snapshot do
    gates = gates()

    %{
      plan_version: 1,
      boundary: :production_default_local_inbox_persistence_plan,
      current_default_mode: :memory_only,
      opt_in_durable_snapshots_available?: true,
      production_default_persistence_allowed?: false,
      default_lifecycle_claim_allowed?: false,
      schema_policy: Mob.Node.BLE.LocalInboxDurableSnapshotSchemaPolicy.snapshot(),
      gate_count: length(gates),
      blocked_gate_count: Enum.count(gates, &(&1.status == :blocked)),
      gates: gates,
      blocked_claims: [
        :default_app_persistence,
        :background_persistence,
        :delivery_record,
        :full_message_resolution,
        :trusted_message_delivery
      ],
      notes: [
        "The current validated local mode keeps app sessions memory-only by default.",
        "Opt-in durable snapshots remain available through explicit operator/session controls.",
        "This plan defines the evidence needed to promote persistence later without changing runtime behavior now."
      ]
    }
  end

  @spec json_snapshot() :: map()
  def json_snapshot do
    snapshot()
    |> JSON.encode!()
    |> JSON.decode!()
  end

  defp gate(id, required_evidence, missing_evidence, blocked_claims, notes) do
    %Gate{
      id: id,
      status: :blocked,
      required_evidence: required_evidence,
      missing_evidence: missing_evidence,
      blocked_claims: blocked_claims,
      notes: notes
    }
  end
end
