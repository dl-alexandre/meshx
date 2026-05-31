defmodule Mob.Node.BLE.LocalPersistenceAcceptance do
  @moduledoc """
  Acceptance boundary for local inbox persistence.

  Durable local inbox storage exists, but it remains an explicit opt-in
  operator capability. This module records the gates that are satisfied by
  the current persistence stack and the gates that still block default app
  lifecycle persistence. It does not save, restore, migrate, prune, schedule
  work, write in the background, resolve beacon refs, fetch envelopes, route,
  ACK, retry, encrypt, or authenticate messages.
  """

  alias Mob.Node.BLE.{
    LocalInboxPersistenceLifecycle,
    LocalInboxPersistenceOperator,
    LocalPersistenceNegativeValidation,
    LocalPersistenceProductionLifecyclePlan
  }

  defmodule Gate do
    @moduledoc false

    @derive {JSON.Encoder,
             only: [
               :id,
               :status,
               :evidence,
               :missing,
               :blocked_claims,
               :notes
             ]}
    @enforce_keys [:id, :status, :evidence, :missing, :blocked_claims, :notes]
    defstruct @enforce_keys

    @type status :: :satisfied | :blocked

    @type t :: %__MODULE__{
            id: atom(),
            status: status(),
            evidence: [binary()],
            missing: [binary()],
            blocked_claims: [atom()],
            notes: [binary()]
          }
  end

  @spec gates() :: [Gate.t()]
  def gates do
    lifecycle = LocalInboxPersistenceLifecycle.snapshot()
    operator = LocalInboxPersistenceOperator.snapshot()
    negative = LocalPersistenceNegativeValidation.snapshot()

    [
      durable_policy_gate(),
      store_boundary_gate(),
      restore_gate(),
      operator_controls_gate(operator),
      production_lifecycle_plan_gate(),
      negative_claim_gate(negative),
      default_lifecycle_gate(lifecycle)
    ]
  end

  @spec snapshot() :: map()
  def snapshot do
    gates = gates()

    %{
      acceptance_version: 1,
      boundary: :opt_in_local_inbox_persistence,
      gates: gates,
      satisfied_count: Enum.count(gates, &(&1.status == :satisfied)),
      blocked_count: Enum.count(gates, &(&1.status == :blocked)),
      default_persistence_claim_allowed?: false,
      background_persistence_claim_allowed?: false,
      delivery_record_claim_allowed?: false,
      production_default_persistence_allowed?: Enum.all?(gates, &(&1.status == :satisfied)),
      blocked_claims: [
        :default_app_persistence,
        :background_persistence,
        :scheduled_cleanup,
        :delivery_record,
        :full_message_resolution,
        :trusted_message_delivery
      ],
      notes: [
        "Current persistence is an explicit operator opt-in for policy-approved read models.",
        "Durable snapshots preserve nearby-message state, not delivery proof.",
        "Default lifecycle persistence remains blocked until migration, cleanup, background-safe write, and on-device restore evidence exist."
      ]
    }
  end

  @spec json_snapshot() :: map()
  def json_snapshot do
    snapshot()
    |> JSON.encode!()
    |> JSON.decode!()
  end

  defp durable_policy_gate do
    gate(
      :durable_snapshot_policy,
      :satisfied,
      [
        "LocalInboxPersistencePolicy creates policy-approved durable snapshots.",
        "Durable snapshots exclude raw transport metadata and source device ids by default."
      ],
      [],
      [:delivery_record, :raw_hardware_evidence_archive],
      ["The persisted shape is a read model, not raw hardware evidence."]
    )
  end

  defp store_boundary_gate do
    gate(
      :store_boundary,
      :satisfied,
      [
        "LocalInboxStore.save/2 and load/1 persist only durable snapshot values.",
        "LocalInboxStore.list/1 and prune_expired/1 expose deterministic retention state with an injected clock."
      ],
      [],
      [:background_persistence, :scheduled_cleanup],
      ["Store maintenance is caller-driven and does not schedule cleanup."]
    )
  end

  defp restore_gate do
    gate(
      :read_model_restore,
      :satisfied,
      [
        "LocalInboxDurableSnapshot.to_read_model/2 restores queryable nearby_messages.",
        "LocalInboxStore.load_read_model/2 composes durable load plus read-model restore."
      ],
      [],
      [:full_message_resolution, :delivery_record],
      ["Restored beacon refs remain unresolved pointers."]
    )
  end

  defp operator_controls_gate(operator) do
    required_actions = [
      :status,
      :save_snapshot,
      :restore_snapshot,
      :prune_expired,
      :clear_snapshot,
      :clear_all
    ]

    actions = Enum.map(operator.actions, & &1.id)
    missing = Enum.reject(required_actions, &(&1 in actions))

    gate(
      :operator_controls,
      if(missing == [] and operator.default_persistence_enabled? == false,
        do: :satisfied,
        else: :blocked
      ),
      [
        "LocalInboxPersistenceOperator exposes status, save, restore, prune, clear-one, and clear-all controls."
      ],
      Enum.map(missing, &"Missing operator action #{inspect(&1)}."),
      [:default_app_persistence, :background_persistence],
      ["Operator controls are explicit actions and do not enable default lifecycle persistence."]
    )
  end

  defp negative_claim_gate(negative) do
    blocked? =
      negative.default_persistence_claims_allowed? == false and
        negative.background_persistence_claims_allowed? == false

    gate(
      :negative_claim_validation,
      if(blocked?, do: :satisfied, else: :blocked),
      [
        "LocalPersistenceNegativeValidation blocks default, delivery-record, raw-evidence, and background persistence claims."
      ],
      if(blocked?,
        do: [],
        else: ["Persistence negative validation no longer blocks required claims."]
      ),
      [:default_app_persistence, :background_persistence, :delivery_record],
      ["Negative validation prevents opt-in snapshots from being promoted into broader claims."]
    )
  end

  defp production_lifecycle_plan_gate do
    plan = LocalPersistenceProductionLifecyclePlan.snapshot()

    required_gates = [
      :default_lifecycle_decision,
      :schema_migration_policy,
      :scheduled_cleanup_worker,
      :background_safe_writer,
      :on_device_restore_fixture,
      :release_artifact_evidence
    ]

    present_gates = Enum.map(plan.gates, & &1.id)
    missing_gates = Enum.reject(required_gates, &(&1 in present_gates))

    gate(
      :production_lifecycle_plan,
      if(missing_gates == [] and plan.production_default_persistence_allowed? == false,
        do: :satisfied,
        else: :blocked
      ),
      [
        "LocalPersistenceProductionLifecyclePlan records default decision, migration, cleanup, background-safe writer, on-device restore, and release evidence gates."
      ],
      Enum.map(missing_gates, &"Missing production lifecycle plan gate #{inspect(&1)}."),
      [:default_app_persistence, :background_persistence, :delivery_record],
      ["The plan structures future work without enabling default lifecycle persistence."]
    )
  end

  defp default_lifecycle_gate(lifecycle) do
    missing =
      lifecycle.production_default_gate
      |> Map.fetch!(:missing_evidence)

    gate(
      :production_default_lifecycle,
      :blocked,
      [],
      missing,
      [:default_app_persistence, :background_persistence, :scheduled_cleanup],
      [
        "Default app lifecycle persistence is intentionally blocked.",
        "This gate requires product approval plus implementation and on-device restore evidence."
      ]
    )
  end

  defp gate(id, status, evidence, missing, blocked_claims, notes) do
    %Gate{
      id: id,
      status: status,
      evidence: evidence,
      missing: missing,
      blocked_claims: blocked_claims,
      notes: notes
    }
  end
end
