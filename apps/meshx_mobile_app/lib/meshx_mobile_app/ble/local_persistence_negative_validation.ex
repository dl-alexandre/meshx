defmodule MeshxMobileApp.BLE.LocalPersistenceNegativeValidation do
  @moduledoc """
  Negative validation matrix for current local inbox persistence claims.

  The current advert-only mode has a durable snapshot boundary and opt-in
  Session save/restore hooks, but production default persistence remains
  gated. This module records cases that must stay blocked from default
  app lifecycle persistence, delivery records, background writes, or
  beacon resolution claims. It does not save, restore, migrate, prune,
  schedule work, start background services, resolve beacon refs, fetch
  envelopes, route, ACK, retry, or encrypt data.
  """

  defmodule Case do
    @moduledoc false

    @derive {JSON.Encoder,
             only: [
               :id,
               :input,
               :blocked_claims,
               :expected_decision,
               :implementation_evidence,
               :required_before_allowed,
               :notes
             ]}
    @enforce_keys [
      :id,
      :input,
      :blocked_claims,
      :expected_decision,
      :implementation_evidence,
      :required_before_allowed,
      :notes
    ]
    defstruct @enforce_keys
  end

  alias MeshxMobileApp.BLE.{
    LocalInbox,
    BeaconInbox,
    LocalInboxDurableSnapshotSchemaPolicy,
    LocalInboxPersistenceLifecycle,
    LocalInboxPersistencePolicy,
    LocalInboxPersistenceProfile
  }

  alias MeshxMobileApp.BLE.Events.ReceivedMessageBeacon

  @cases [
    %{
      id: :opt_in_snapshot_as_default_lifecycle,
      input: :opt_in_durable_session_snapshot,
      blocked_claims: [
        :default_app_persistence,
        :automatic_restore,
        :production_lifecycle_persistence
      ],
      expected_decision: :operator_opt_in_only,
      required_before_allowed: [
        :product_persistence_decision,
        :migration_plan,
        :on_device_restore_validation,
        :operator_storage_controls
      ],
      notes: [
        "Opt-in durable snapshots are available, but default sessions remain memory-only.",
        "Session options do not make persistence production default."
      ]
    },
    %{
      id: :durable_beacon_ref_as_delivery_record,
      input: :persisted_unresolved_beacon_ref,
      blocked_claims: [
        :message_delivery_record,
        :full_message_available,
        :trusted_delivery
      ],
      expected_decision: :persisted_pointer_only,
      required_before_allowed: [
        :validated_full_message_resolution_transport,
        :canonical_envelope_replay_after_fetch,
        :authenticated_authorship_if_trust_claimed
      ],
      notes: [
        "Persisting a beacon ref preserves an unresolved pointer.",
        "A hash-only ref is not proof that the full MessageEnvelope was delivered."
      ]
    },
    %{
      id: :manual_prune_as_scheduled_cleanup,
      input: :local_inbox_store_prune_expired,
      blocked_claims: [
        :scheduled_cleanup,
        :background_cleanup_worker,
        :production_retention_enforcement
      ],
      expected_decision: :manual_operator_cleanup_only,
      required_before_allowed: [
        :scheduled_cleanup_execution,
        :injected_clock_cleanup_tests,
        :operator_visible_cleanup_status
      ],
      notes: [
        "The store can prune when called, but no scheduler or worker exists.",
        "Retention enforcement remains caller-driven."
      ]
    },
    %{
      id: :foreground_save_as_background_safe_write,
      input: :session_stop_save_hook,
      blocked_claims: [
        :background_safe_write,
        :mobile_lifecycle_persistence,
        :restart_survival_claim
      ],
      expected_decision: :foreground_or_session_bound_write,
      required_before_allowed: [
        :background_safe_write_policy,
        :android_lifecycle_validation,
        :ios_lifecycle_validation,
        :app_restart_restore_evidence
      ],
      notes: [
        "Foreground/session-bound hooks are not background lifecycle proof.",
        "Mobile OS throttling and process death behavior remain unvalidated."
      ]
    },
    %{
      id: :durable_snapshot_as_raw_evidence_archive,
      input: :durable_local_inbox_snapshot,
      blocked_claims: [
        :raw_hardware_evidence_archive,
        :forensic_log_archive,
        :transport_metadata_persistence
      ],
      expected_decision: :policy_approved_read_model_only,
      required_before_allowed: [
        :hardware_evidence_manifest_attachment,
        :raw_log_retention_policy,
        :operator_archive_controls
      ],
      notes: [
        "Durable snapshots intentionally exclude raw transport metadata by default.",
        "Release hardware evidence must be attached separately as logs or validation ledgers."
      ]
    },
    %{
      id: :current_schema_policy_as_migration_plan,
      input: :current_version_schema_normalization,
      blocked_claims: [
        :automatic_schema_migration,
        :production_upgrade_safe,
        :default_app_persistence
      ],
      expected_decision: :current_schema_only,
      required_before_allowed: [
        :versioned_migration_plan,
        :upgrade_and_rollback_fixtures,
        :corrupt_snapshot_recovery_policy,
        :release_rollback_policy
      ],
      notes: [
        "Current-version JSON normalization is not a forward migration plan.",
        "Production-default persistence needs explicit upgrade, rollback, and corrupt snapshot evidence."
      ]
    }
  ]

  @spec cases() :: [Case.t()]
  def cases do
    Enum.map(@cases, fn spec ->
      spec
      |> Map.put(:implementation_evidence, implementation_evidence(spec.id))
      |> then(&struct!(Case, &1))
    end)
  end

  @spec snapshot() :: map()
  def snapshot do
    cases = cases()

    %{
      validation_version: 1,
      boundary: :current_opt_in_local_read_model_persistence,
      cases: cases,
      case_count: length(cases),
      blocked_claims: blocked_claims(cases),
      default_persistence_claims_allowed?: false,
      delivery_record_claims_allowed?: false,
      background_persistence_claims_allowed?: false,
      notes: [
        "Current persistence is a local read-model snapshot boundary.",
        "Negative validation cases prevent opt-in durable snapshots from becoming default lifecycle or delivery claims.",
        "Future production persistence must replace these blocked outcomes with implementation-backed positive and negative fixtures."
      ]
    }
  end

  @spec json_snapshot() :: map()
  def json_snapshot do
    snapshot()
    |> JSON.encode!()
    |> JSON.decode!()
  end

  defp blocked_claims(cases) do
    cases
    |> Enum.flat_map(& &1.blocked_claims)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp implementation_evidence(:opt_in_snapshot_as_default_lifecycle) do
    lifecycle = LocalInboxPersistenceLifecycle.snapshot()

    %{
      source_modules: [
        "LocalInboxPersistenceLifecycle",
        "LocalInboxPersistenceProfile"
      ],
      default_mode: lifecycle.default_decision.default_mode,
      durable_default_enabled?: lifecycle.default_decision.durable_default_enabled?,
      restore_default_enabled?: lifecycle.default_decision.restore_default_enabled?,
      opt_in_mode: lifecycle.opt_in_profile.mode,
      opt_in_enabled?: lifecycle.opt_in_profile.enabled?,
      opt_in_restore_on_start?: lifecycle.opt_in_profile.restore_on_start?
    }
  end

  defp implementation_evidence(:durable_beacon_ref_as_delivery_record) do
    {:ok, durable} =
      beacon_only_snapshot()
      |> LocalInboxPersistencePolicy.durable_snapshot(persisted_at: 100)

    [ref] = durable.unresolved_beacon_refs

    %{
      source_modules: [
        "LocalInbox",
        "LocalInboxPersistencePolicy"
      ],
      persisted_kind: ref.kind,
      delivery_state: ref.delivery_state,
      has_message_id_hash?: Map.has_key?(ref, :message_id_hash),
      has_envelope_wire?: Map.has_key?(ref, :envelope_wire),
      full_message_count: length(durable.full_messages),
      unresolved_beacon_ref_count: length(durable.unresolved_beacon_refs)
    }
  end

  defp implementation_evidence(:manual_prune_as_scheduled_cleanup) do
    profile = LocalInboxPersistenceProfile.opt_in_durable()

    %{
      source_modules: ["LocalInboxPersistenceProfile"],
      cleanup_scheduled?: profile.cleanup.scheduled?,
      cleanup_operator_command: profile.cleanup.operator_command,
      cleanup_notes: profile.cleanup.notes
    }
  end

  defp implementation_evidence(:foreground_save_as_background_safe_write) do
    profile = LocalInboxPersistenceProfile.opt_in_durable()

    %{
      source_modules: ["LocalInboxPersistenceProfile"],
      save_triggers: profile.save_triggers,
      has_session_stop_save_hook?: :session_stop in profile.save_triggers,
      has_background_save_trigger?: :background_transition in profile.save_triggers,
      cleanup_scheduled?: profile.cleanup.scheduled?
    }
  end

  defp implementation_evidence(:durable_snapshot_as_raw_evidence_archive) do
    {:ok, durable} =
      beacon_only_snapshot()
      |> LocalInboxPersistencePolicy.durable_snapshot(persisted_at: 100)

    %{
      source_modules: ["LocalInboxPersistencePolicy"],
      excluded_fields: durable.excluded_fields,
      persists_raw_transport_metadata?: durable.policy.persist_raw_transport_metadata?,
      unresolved_beacon_ref_count: length(durable.unresolved_beacon_refs)
    }
  end

  defp implementation_evidence(:current_schema_policy_as_migration_plan) do
    policy = LocalInboxDurableSnapshotSchemaPolicy.snapshot()

    %{
      source_modules: ["LocalInboxDurableSnapshotSchemaPolicy"],
      current_schema_version: policy.current_schema_version,
      supported_schema_versions: policy.supported_schema_versions,
      json_decoded_current_version_restore_supported?:
        policy.json_decoded_current_version_restore_supported?,
      future_schema_versions_supported?: policy.future_schema_versions_supported?,
      production_default_persistence_allowed?: policy.production_default_persistence_allowed?,
      policy_blocked_claims: policy.blocked_claims
    }
  end

  defp beacon_event do
    %ReceivedMessageBeacon{
      beacon_version: 1,
      envelope_version: 1,
      payload_kind: "TX",
      message_id_hash: <<2, 2, 2, 2, 2, 2, 2, 2>>,
      sender_peer_id_hash: <<3, 3, 3, 3, 3, 3, 3, 3>>,
      received_device_id: "AA:02",
      received_at: 90,
      rssi: -70,
      raw_transport_metadata: %{adapter: :fixture}
    }
  end

  defp beacon_only_snapshot do
    inbox = LocalInbox.ingest(LocalInbox.new(), beacon_event())

    %{
      transport_profile: nil,
      full_messages: [],
      unresolved_beacon_refs: BeaconInbox.snapshot(inbox.beacon_inbox),
      capability_notes: ["negative validation fixture"]
    }
  end
end
