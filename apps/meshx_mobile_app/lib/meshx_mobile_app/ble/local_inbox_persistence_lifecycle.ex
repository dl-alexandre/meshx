defmodule MeshxMobileApp.BLE.LocalInboxPersistenceLifecycle do
  @moduledoc """
  Persistence lifecycle decision for the advertisement-only local inbox.

  This module records how persistence is allowed to behave in the current
  validated local mode. It is policy data only: it does not save, restore,
  migrate, prune, schedule work, start background services, resolve beacon
  refs, fetch envelopes, route, ACK, retry, or encrypt data.
  """

  alias MeshxMobileApp.BLE.{LocalInboxPersistenceOperator, LocalInboxPersistenceProfile}

  @spec snapshot() :: map()
  def snapshot do
    memory = LocalInboxPersistenceProfile.memory_only()
    durable = LocalInboxPersistenceProfile.opt_in_durable()

    %{
      lifecycle_version: 1,
      mode: :advertisement_only_local_mesh,
      default_profile: profile_summary(memory),
      opt_in_profile: profile_summary(durable),
      default_decision: default_decision(),
      storage_scope: storage_scope(),
      production_default_gate: production_default_gate(),
      operator_actions: operator_actions(),
      operator_controls: LocalInboxPersistenceOperator.snapshot(),
      unsupported_claims: unsupported_claims(),
      notes: [
        "Default app sessions remain memory-only in the validated advert-only local mode.",
        "Opt-in durable snapshots are available for policy-approved local read models.",
        "Durable snapshots do not make beacon refs resolvable or delivered."
      ]
    }
  end

  @spec json_snapshot() :: map()
  def json_snapshot do
    snapshot()
    |> JSON.encode!()
    |> JSON.decode!()
  end

  defp default_decision do
    %{
      decision_outcome: :keep_memory_only_default,
      decision_status: :selected_for_current_validated_mode,
      default_mode: :memory_only,
      durable_default_enabled?: false,
      opt_in_durable_allowed?: true,
      restore_default_enabled?: false,
      production_default_reconsideration_gate: :production_default_local_inbox_persistence_plan,
      rationale: [
        "The current validated mode is nearby observation, not guaranteed message delivery.",
        "Automatic durable writes need production lifecycle evidence before becoming default.",
        "Memory-only default avoids implying that local observations are durable delivery records."
      ]
    }
  end

  defp production_default_gate do
    %{
      status: :blocked,
      required_before_default: [
        :migration_plan,
        :scheduled_cleanup_execution,
        :background_safe_write_policy,
        :operator_storage_controls,
        :on_device_restore_validation
      ],
      missing_evidence: [
        "Migration or schema-upgrade plan for durable local inbox snapshots.",
        "Scheduled cleanup execution with injected-clock test evidence.",
        "Background-safe write behavior for mobile lifecycle transitions.",
        "Operator controls for clearing or disabling local durable snapshots.",
        "On-device restore validation across app restart."
      ]
    }
  end

  defp storage_scope do
    %{
      default_storage_mode: :memory_only,
      opt_in_storage_mode: :durable_local_read_model_snapshot,
      stored_when_opted_in: [
        :canonical_full_message_read_models,
        :unresolved_beacon_ref_read_models,
        :capability_notes,
        :transport_profile
      ],
      never_stored: [
        :raw_transport_metadata,
        :crypto_key_material,
        :trust_store,
        :replay_protection_state,
        :routing_table,
        :fetch_attempt_transport_state
      ],
      not_evidence_of: [
        :message_delivery,
        :full_message_resolution,
        :authenticated_authorship,
        :trusted_message,
        :background_operation
      ],
      notes: [
        "Opt-in persistence stores a local inbox read model only.",
        "Beacon refs remain unresolved pointers after restore.",
        "Memory-only remains the default for the current validated advert-only mode."
      ]
    }
  end

  defp operator_actions do
    [
      %{
        id: :enable_opt_in_durable,
        status: :available,
        session_options:
          session_options_map(
            LocalInboxPersistenceProfile.session_options(
              LocalInboxPersistenceProfile.opt_in_durable()
            )
          ),
        notes: [
          "Use only for local read-model snapshots.",
          "Does not persist raw transport metadata."
        ]
      },
      %{
        id: :restore_opt_in_snapshot,
        status: :available,
        session_options:
          session_options_map(
            persist_local_inbox?: true,
            restore_local_inbox?: true,
            local_inbox_snapshot_id: :default
          ),
        notes: [
          "Restore exposes a read model without mutating the live local inbox."
        ]
      },
      %{
        id: :prune_expired_snapshots,
        status: :manual_only,
        command: "LocalInboxStore.prune_expired(now: <timestamp_ms>)",
        notes: [
          "Cleanup remains caller-driven.",
          "No scheduled cleanup worker exists."
        ]
      }
    ]
  end

  defp profile_summary(profile) do
    %{
      mode: profile.mode,
      enabled?: profile.enabled?,
      restore_on_start?: profile.restore_on_start?,
      snapshot_id: profile.snapshot_id,
      save_triggers: profile.save_triggers,
      cleanup: profile.cleanup,
      session_options: session_options_map(profile.session_options),
      operator_notes: profile.operator_notes
    }
  end

  defp session_options_map(opts), do: Map.new(opts)

  defp unsupported_claims do
    [
      "Persistence does not provide delivery guarantees.",
      "Persistence does not resolve legacy beacon refs.",
      "Persistence does not authenticate message authorship.",
      "Persistence does not run in the background.",
      "Persistence does not create routing, ACK, retry, or fetch behavior."
    ]
  end
end
