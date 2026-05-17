defmodule MeshxMobileApp.BLE.LocalReleaseCandidateEvidenceReview do
  @moduledoc """
  Pure review contract for advert-only local release-candidate evidence.

  This module validates the shape of operator-supplied release evidence:
  generated manifest paths, concrete hardware attachment metadata, and
  operator wording notes. It does not read files, inspect hardware, run
  adb, scan, advertise, fetch, route, persist, ACK, retry, encrypt, or run
  background work.
  """

  alias MeshxMobileApp.BLE.LocalReleaseEvidenceManifest

  defmodule HardwareAttachment do
    @moduledoc false

    @derive {JSON.Encoder,
             only: [
               :device_model,
               :os_or_api_version,
               :role,
               :command_or_harness,
               :summary_path,
               :raw_log_path,
               :gate_ids,
               :evidence_types_by_gate
             ]}
    @enforce_keys [
      :device_model,
      :os_or_api_version,
      :role,
      :command_or_harness,
      :summary_path,
      :raw_log_path,
      :gate_ids,
      :evidence_types_by_gate,
      :gate_ids_container_valid?,
      :evidence_types_by_gate_container_valid?
    ]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            device_model: binary() | nil,
            os_or_api_version: binary() | nil,
            role: binary() | nil,
            command_or_harness: binary() | nil,
            summary_path: binary() | nil,
            raw_log_path: binary() | nil,
            gate_ids: [atom()],
            evidence_types_by_gate: %{optional(atom()) => atom()}
          }
  end

  defmodule OperatorNotes do
    @moduledoc false

    @derive {JSON.Encoder,
             only: [
               :notes_path,
               :allowed_wording,
               :blocked_claims_called_out,
               :open_hardware_gate_ids_called_out,
               :readiness_manifest_path,
               :completion_audit_path,
               :completion_audit_plain_text_path,
               :focused_remaining_items_audit_path,
               :focused_remaining_items_plain_text_path,
               :direct_full_mx_aux_validation_checklist_path,
               :upstream_patch_maintainer_handoff_path,
               :completion_blocker_matrix_path,
               :release_manifest_path,
               :recent_evidence_inventory_path,
               :persistence_lifecycle_plan_path,
               :lifecycle_review_path,
               :ios_parity_review_path,
               :full_resolution_review_path,
               :known_good_transport_review_path,
               :multi_hop_review_path,
               :routing_review_path,
               :security_review_path,
               :ux_review_path
             ]}
    @enforce_keys [
      :notes_path,
      :allowed_wording,
      :blocked_claims_called_out,
      :open_hardware_gate_ids_called_out,
      :readiness_manifest_path,
      :completion_audit_path,
      :completion_audit_plain_text_path,
      :focused_remaining_items_audit_path,
      :focused_remaining_items_plain_text_path,
      :direct_full_mx_aux_validation_checklist_path,
      :upstream_patch_maintainer_handoff_path,
      :completion_blocker_matrix_path,
      :release_manifest_path,
      :recent_evidence_inventory_path,
      :persistence_lifecycle_plan_path,
      :lifecycle_review_path,
      :ios_parity_review_path,
      :full_resolution_review_path,
      :known_good_transport_review_path,
      :multi_hop_review_path,
      :routing_review_path,
      :security_review_path,
      :ux_review_path,
      :blocked_claims_called_out_container_valid?,
      :open_hardware_gate_ids_called_out_container_valid?
    ]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            notes_path: binary() | nil,
            allowed_wording: binary() | nil,
            blocked_claims_called_out: [atom()],
            open_hardware_gate_ids_called_out: [atom()],
            readiness_manifest_path: binary() | nil,
            completion_audit_path: binary() | nil,
            completion_audit_plain_text_path: binary() | nil,
            focused_remaining_items_audit_path: binary() | nil,
            focused_remaining_items_plain_text_path: binary() | nil,
            direct_full_mx_aux_validation_checklist_path: binary() | nil,
            upstream_patch_maintainer_handoff_path: binary() | nil,
            completion_blocker_matrix_path: binary() | nil,
            release_manifest_path: binary() | nil,
            recent_evidence_inventory_path: binary() | nil,
            persistence_lifecycle_plan_path: binary() | nil,
            lifecycle_review_path: binary() | nil,
            ios_parity_review_path: binary() | nil,
            full_resolution_review_path: binary() | nil,
            known_good_transport_review_path: binary() | nil,
            multi_hop_review_path: binary() | nil,
            routing_review_path: binary() | nil,
            security_review_path: binary() | nil,
            ux_review_path: binary() | nil
          }
  end

  defmodule PersistenceLifecycleSummary do
    @moduledoc false

    @derive {JSON.Encoder,
             only: [
               :plan_path,
               :plan_version,
               :boundary,
               :current_default_mode,
               :opt_in_durable_snapshots_available?,
               :production_default_persistence_allowed?,
               :default_lifecycle_claim_allowed?,
               :gate_count,
               :blocked_gate_count
             ]}
    @enforce_keys [
      :plan_path,
      :plan_version,
      :boundary,
      :current_default_mode,
      :opt_in_durable_snapshots_available?,
      :production_default_persistence_allowed?,
      :default_lifecycle_claim_allowed?,
      :gate_count,
      :blocked_gate_count
    ]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            plan_path: binary() | nil,
            plan_version: non_neg_integer(),
            boundary: atom() | binary() | nil,
            current_default_mode: atom() | binary() | nil,
            opt_in_durable_snapshots_available?: boolean(),
            production_default_persistence_allowed?: boolean(),
            default_lifecycle_claim_allowed?: boolean(),
            gate_count: non_neg_integer(),
            blocked_gate_count: non_neg_integer()
          }
  end

  defmodule UxReviewSummary do
    @moduledoc false

    @derive {JSON.Encoder,
             only: [
               :review_path,
               :review_version,
               :boundary,
               :status,
               :on_device_ux_evidence_complete?,
               :production_ux_claim_allowed?,
               :delivery_claim_allowed?,
               :trusted_delivery_claim_allowed?,
               :routing_claim_allowed?,
               :target_device_count,
               :all_target_devices_have_state_coverage?,
               :all_target_devices_have_interaction_coverage?,
               :all_target_devices_have_selected_detail_coverage?,
               :all_target_devices_have_selected_detail_copy_anchors?,
               :all_target_devices_copy_reviewed?,
               :all_target_devices_density_reviewed?
             ]}
    @enforce_keys [
      :review_path,
      :review_version,
      :boundary,
      :status,
      :on_device_ux_evidence_complete?,
      :production_ux_claim_allowed?,
      :delivery_claim_allowed?,
      :trusted_delivery_claim_allowed?,
      :routing_claim_allowed?,
      :target_device_count,
      :all_target_devices_have_state_coverage?,
      :all_target_devices_have_interaction_coverage?,
      :all_target_devices_have_selected_detail_coverage?,
      :all_target_devices_have_selected_detail_copy_anchors?,
      :all_target_devices_copy_reviewed?,
      :all_target_devices_density_reviewed?
    ]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            review_path: binary() | nil,
            review_version: non_neg_integer(),
            boundary: atom() | binary() | nil,
            status: atom() | binary() | nil,
            on_device_ux_evidence_complete?: boolean(),
            production_ux_claim_allowed?: boolean(),
            delivery_claim_allowed?: boolean(),
            trusted_delivery_claim_allowed?: boolean(),
            routing_claim_allowed?: boolean(),
            target_device_count: non_neg_integer(),
            all_target_devices_have_state_coverage?: boolean(),
            all_target_devices_have_interaction_coverage?: boolean(),
            all_target_devices_have_selected_detail_coverage?: boolean(),
            all_target_devices_have_selected_detail_copy_anchors?: boolean(),
            all_target_devices_copy_reviewed?: boolean(),
            all_target_devices_density_reviewed?: boolean()
          }
  end

  defmodule SecurityReviewSummary do
    @moduledoc false

    @derive {JSON.Encoder,
             only: [
               :review_path,
               :review_version,
               :boundary,
               :status,
               :security_release_evidence_complete?,
               :authenticated_peer_identity_claim_allowed?,
               :authenticated_message_claim_allowed?,
               :trusted_message_claim_allowed?,
               :trusted_delivery_claim_allowed?
             ]}
    @enforce_keys [
      :review_path,
      :review_version,
      :boundary,
      :status,
      :security_release_evidence_complete?,
      :authenticated_peer_identity_claim_allowed?,
      :authenticated_message_claim_allowed?,
      :trusted_message_claim_allowed?,
      :trusted_delivery_claim_allowed?
    ]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            review_path: binary() | nil,
            review_version: non_neg_integer(),
            boundary: atom() | binary() | nil,
            status: atom() | binary() | nil,
            security_release_evidence_complete?: boolean(),
            authenticated_peer_identity_claim_allowed?: boolean(),
            authenticated_message_claim_allowed?: boolean(),
            trusted_message_claim_allowed?: boolean(),
            trusted_delivery_claim_allowed?: boolean()
          }
  end

  defmodule FullResolutionReviewSummary do
    @moduledoc false

    @derive {JSON.Encoder,
             only: [
               :review_path,
               :review_version,
               :boundary,
               :status,
               :full_resolution_transport_evidence_complete?,
               :real_fetch_transport_validated?,
               :full_message_resolution_claim_allowed?,
               :known_good_transport_claim_allowed?,
               :gatt_fetch_success_claim_allowed?,
               :message_delivery_claim_allowed?,
               :trusted_message_claim_allowed?
             ]}
    @enforce_keys [
      :review_path,
      :review_version,
      :boundary,
      :status,
      :full_resolution_transport_evidence_complete?,
      :real_fetch_transport_validated?,
      :full_message_resolution_claim_allowed?,
      :known_good_transport_claim_allowed?,
      :gatt_fetch_success_claim_allowed?,
      :message_delivery_claim_allowed?,
      :trusted_message_claim_allowed?
    ]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            review_path: binary() | nil,
            review_version: non_neg_integer(),
            boundary: atom() | binary() | nil,
            status: atom() | binary() | nil,
            full_resolution_transport_evidence_complete?: boolean(),
            real_fetch_transport_validated?: boolean(),
            full_message_resolution_claim_allowed?: boolean(),
            known_good_transport_claim_allowed?: boolean(),
            gatt_fetch_success_claim_allowed?: boolean(),
            message_delivery_claim_allowed?: boolean(),
            trusted_message_claim_allowed?: boolean()
          }
  end

  defmodule KnownGoodTransportReviewSummary do
    @moduledoc false

    @derive {JSON.Encoder,
             only: [
               :review_path,
               :review_version,
               :boundary,
               :status,
               :known_good_transport_evidence_complete?,
               :known_good_transport_claim_allowed?,
               :gatt_fetch_success_claim_allowed?,
               :full_message_resolution_claim_allowed?,
               :message_delivery_claim_allowed?
             ]}
    @enforce_keys [
      :review_path,
      :review_version,
      :boundary,
      :status,
      :known_good_transport_evidence_complete?,
      :known_good_transport_claim_allowed?,
      :gatt_fetch_success_claim_allowed?,
      :full_message_resolution_claim_allowed?,
      :message_delivery_claim_allowed?
    ]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            review_path: binary() | nil,
            review_version: non_neg_integer(),
            boundary: atom() | binary() | nil,
            status: atom() | binary() | nil,
            known_good_transport_evidence_complete?: boolean(),
            known_good_transport_claim_allowed?: boolean(),
            gatt_fetch_success_claim_allowed?: boolean(),
            full_message_resolution_claim_allowed?: boolean(),
            message_delivery_claim_allowed?: boolean()
          }
  end

  defmodule MultiHopReviewSummary do
    @moduledoc false

    @derive {JSON.Encoder,
             only: [
               :review_path,
               :review_version,
               :boundary,
               :status,
               :multi_hop_hardware_evidence_complete?,
               :multi_hop_physical_proof_present?,
               :multi_hop_hardware_gossip_claim_allowed?,
               :routed_delivery_claim_allowed?,
               :guaranteed_delivery_claim_allowed?,
               :trusted_delivery_claim_allowed?,
               :background_operation_claim_allowed?
             ]}
    @enforce_keys [
      :review_path,
      :review_version,
      :boundary,
      :status,
      :multi_hop_hardware_evidence_complete?,
      :multi_hop_physical_proof_present?,
      :multi_hop_hardware_gossip_claim_allowed?,
      :routed_delivery_claim_allowed?,
      :guaranteed_delivery_claim_allowed?,
      :trusted_delivery_claim_allowed?,
      :background_operation_claim_allowed?
    ]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            review_path: binary() | nil,
            review_version: non_neg_integer(),
            boundary: atom() | binary() | nil,
            status: atom() | binary() | nil,
            multi_hop_hardware_evidence_complete?: boolean(),
            multi_hop_physical_proof_present?: boolean(),
            multi_hop_hardware_gossip_claim_allowed?: boolean(),
            routed_delivery_claim_allowed?: boolean(),
            guaranteed_delivery_claim_allowed?: boolean(),
            trusted_delivery_claim_allowed?: boolean(),
            background_operation_claim_allowed?: boolean()
          }
  end

  defmodule IOSParityReviewSummary do
    @moduledoc false

    @derive {JSON.Encoder,
             only: [
               :review_path,
               :review_version,
               :boundary,
               :status,
               :ios_hardware_evidence_complete?,
               :ios_participation_claim_allowed?,
               :ios_hardware_claim_allowed?,
               :ios_legacy_beacon_observe_claim_allowed?,
               :ios_legacy_beacon_gossip_claim_allowed?,
               :ios_full_envelope_advert_claim_allowed?,
               :ios_background_ble_claim_allowed?,
               :ios_parity_claim_allowed?
             ]}
    @enforce_keys [
      :review_path,
      :review_version,
      :boundary,
      :status,
      :ios_hardware_evidence_complete?,
      :ios_participation_claim_allowed?,
      :ios_hardware_claim_allowed?,
      :ios_legacy_beacon_observe_claim_allowed?,
      :ios_legacy_beacon_gossip_claim_allowed?,
      :ios_full_envelope_advert_claim_allowed?,
      :ios_background_ble_claim_allowed?,
      :ios_parity_claim_allowed?
    ]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            review_path: binary() | nil,
            review_version: non_neg_integer(),
            boundary: atom() | binary() | nil,
            status: atom() | binary() | nil,
            ios_hardware_evidence_complete?: boolean(),
            ios_participation_claim_allowed?: boolean(),
            ios_hardware_claim_allowed?: boolean(),
            ios_legacy_beacon_observe_claim_allowed?: boolean(),
            ios_legacy_beacon_gossip_claim_allowed?: boolean(),
            ios_full_envelope_advert_claim_allowed?: boolean(),
            ios_background_ble_claim_allowed?: boolean(),
            ios_parity_claim_allowed?: boolean()
          }
  end

  defmodule LifecycleReviewSummary do
    @moduledoc false

    @derive {JSON.Encoder,
             only: [
               :review_path,
               :review_version,
               :boundary,
               :status,
               :lifecycle_hardware_evidence_complete?,
               :android_foreground_service_claim_allowed?,
               :android_background_ble_claim_allowed?,
               :ios_background_claim_allowed?,
               :background_ble_claim_allowed?,
               :restart_claim_allowed?,
               :scheduled_retry_claim_allowed?,
               :background_gossip_claim_allowed?,
               :delivery_claim_allowed?
             ]}
    @enforce_keys [
      :review_path,
      :review_version,
      :boundary,
      :status,
      :lifecycle_hardware_evidence_complete?,
      :android_foreground_service_claim_allowed?,
      :android_background_ble_claim_allowed?,
      :ios_background_claim_allowed?,
      :background_ble_claim_allowed?,
      :restart_claim_allowed?,
      :scheduled_retry_claim_allowed?,
      :background_gossip_claim_allowed?,
      :delivery_claim_allowed?
    ]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            review_path: binary() | nil,
            review_version: non_neg_integer(),
            boundary: atom() | binary() | nil,
            status: atom() | binary() | nil,
            lifecycle_hardware_evidence_complete?: boolean(),
            android_foreground_service_claim_allowed?: boolean(),
            android_background_ble_claim_allowed?: boolean(),
            ios_background_claim_allowed?: boolean(),
            background_ble_claim_allowed?: boolean(),
            restart_claim_allowed?: boolean(),
            scheduled_retry_claim_allowed?: boolean(),
            background_gossip_claim_allowed?: boolean(),
            delivery_claim_allowed?: boolean()
          }
  end

  defmodule RoutingReviewSummary do
    @moduledoc false

    @derive {JSON.Encoder,
             only: [
               :review_path,
               :review_version,
               :boundary,
               :status,
               :production_routing_evidence_complete?,
               :route_table_claim_allowed?,
               :route_selection_claim_allowed?,
               :forwarding_claim_allowed?,
               :routed_delivery_claim_allowed?,
               :guaranteed_delivery_claim_allowed?,
               :multi_hop_hardware_claim_allowed?
             ]}
    @enforce_keys [
      :review_path,
      :review_version,
      :boundary,
      :status,
      :production_routing_evidence_complete?,
      :route_table_claim_allowed?,
      :route_selection_claim_allowed?,
      :forwarding_claim_allowed?,
      :routed_delivery_claim_allowed?,
      :guaranteed_delivery_claim_allowed?,
      :multi_hop_hardware_claim_allowed?
    ]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            review_path: binary() | nil,
            review_version: non_neg_integer(),
            boundary: atom() | binary() | nil,
            status: atom() | binary() | nil,
            production_routing_evidence_complete?: boolean(),
            route_table_claim_allowed?: boolean(),
            route_selection_claim_allowed?: boolean(),
            forwarding_claim_allowed?: boolean(),
            routed_delivery_claim_allowed?: boolean(),
            guaranteed_delivery_claim_allowed?: boolean(),
            multi_hop_hardware_claim_allowed?: boolean()
          }
  end

  @allowed_wording "MeshX can show messages seen nearby from passive BLE advertisement observations."
  @full_resolution_review_boundary :full_message_resolution_transport_evidence_review
  @ios_parity_review_boundary :ios_advert_only_hardware_evidence_review
  @known_good_transport_review_boundary :known_good_transport_evidence_review
  @lifecycle_review_boundary :mobile_ble_lifecycle_hardware_evidence_review
  @multi_hop_review_boundary :multi_hop_hardware_evidence_review
  @persistence_lifecycle_boundary :production_default_local_inbox_persistence_plan
  @routing_review_boundary :production_routing_evidence_review
  @security_review_boundary :local_security_release_evidence_review
  @ux_review_boundary :nearby_messages_on_device_ux_evidence

  @required_blocked_claims [
    :whole_project_complete,
    :guaranteed_delivery,
    :trusted_delivery,
    :authenticated_message_delivery,
    :routed_delivery,
    :multi_hop_hardware_delivery,
    :full_message_resolution_from_beacon_refs,
    :background_mobile_operation,
    :ios_advert_only_participation,
    :direct_full_mx_aux_complete,
    :upstream_patch_migration_complete
  ]

  @required_paths [
    :readiness_manifest_path,
    :completion_audit_path,
    :completion_audit_plain_text_path,
    :focused_remaining_items_audit_path,
    :focused_remaining_items_plain_text_path,
    :direct_full_mx_aux_validation_checklist_path,
    :upstream_patch_maintainer_handoff_path,
    :release_manifest_path,
    :completion_blocker_matrix_path,
    :recent_evidence_inventory_path,
    :advert_gossip_audit_path,
    :persistence_lifecycle_plan_path,
    :lifecycle_review_path,
    :ios_parity_review_path,
    :full_resolution_review_path,
    :known_good_transport_review_path,
    :multi_hop_review_path,
    :routing_review_path,
    :security_review_path,
    :ux_review_path
  ]

  @operator_note_path_fields [
    :notes_path,
    :readiness_manifest_path,
    :completion_audit_path,
    :completion_audit_plain_text_path,
    :focused_remaining_items_audit_path,
    :focused_remaining_items_plain_text_path,
    :direct_full_mx_aux_validation_checklist_path,
    :upstream_patch_maintainer_handoff_path,
    :completion_blocker_matrix_path,
    :release_manifest_path,
    :recent_evidence_inventory_path,
    :persistence_lifecycle_plan_path,
    :lifecycle_review_path,
    :ios_parity_review_path,
    :full_resolution_review_path,
    :known_good_transport_review_path,
    :multi_hop_review_path,
    :routing_review_path,
    :security_review_path,
    :ux_review_path
  ]

  @required_gate_evidence_types %{
    android_legacy_beacon_gossip_one_hop: :android_legacy_beacon_gossip_summary,
    android_full_envelope_advert_pair: :android_full_envelope_advert_summary,
    gatt_known_good_fetch: :standalone_gatt_interop_log,
    advert_gossip_multi_hop_hardware: :multi_hop_hardware_log,
    ios_advert_only_participation: :ios_advert_only_hardware_log
  }

  @spec allowed_wording() :: binary()
  def allowed_wording, do: @allowed_wording

  @spec required_blocked_claims() :: [atom()]
  def required_blocked_claims, do: @required_blocked_claims

  @spec required_gate_evidence_types() :: %{atom() => atom()}
  def required_gate_evidence_types, do: @required_gate_evidence_types

  @spec review(map()) :: map()
  def review(input) when is_map(input) do
    hardware_attachments_input = get_field(input, :hardware_attachments, [])
    operator_notes_input = get_field(input, :operator_notes, %{})

    hardware_attachments =
      hardware_attachments_input
      |> hardware_attachments()

    operator_notes =
      operator_notes_input
      |> operator_notes()

    ux_review =
      input
      |> get_field(:ux_review, %{})
      |> ux_review_summary()

    persistence_lifecycle =
      input
      |> get_field(:persistence_lifecycle, %{})
      |> persistence_lifecycle_summary()

    lifecycle_review =
      input
      |> get_field(:lifecycle_review, %{})
      |> lifecycle_review_summary()

    ios_parity_review =
      input
      |> get_field(:ios_parity_review, %{})
      |> ios_parity_review_summary()

    full_resolution_review =
      input
      |> get_field(:full_resolution_review, %{})
      |> full_resolution_review_summary()

    known_good_transport_review =
      input
      |> get_field(:known_good_transport_review, %{})
      |> known_good_transport_review_summary()

    multi_hop_review =
      input
      |> get_field(:multi_hop_review, %{})
      |> multi_hop_review_summary()

    security_review =
      input
      |> get_field(:security_review, %{})
      |> security_review_summary()

    routing_review =
      input
      |> get_field(:routing_review, %{})
      |> routing_review_summary()

    open_gate_ids = open_hardware_gate_ids()

    missing =
      []
      |> malformed_release_candidate_containers(hardware_attachments_input, operator_notes_input)
      |> missing_required_paths(input)
      |> malformed_required_paths(input)
      |> non_trimmed_required_paths(input)
      |> non_relative_required_paths(input)
      |> missing_persistence_lifecycle(input, persistence_lifecycle)
      |> missing_lifecycle_review(input, lifecycle_review)
      |> missing_ios_parity_review(input, ios_parity_review)
      |> missing_full_resolution_review(input, full_resolution_review)
      |> missing_known_good_transport_review(input, known_good_transport_review)
      |> missing_multi_hop_review(input, multi_hop_review)
      |> missing_routing_review(input, routing_review)
      |> missing_security_review(input, security_review)
      |> missing_ux_review(input, ux_review)
      |> missing_hardware_attachments(hardware_attachments)
      |> missing_operator_notes(input, operator_notes, open_gate_ids)
      |> Enum.reverse()

    %{
      review_version: 1,
      boundary: :advert_only_local_release_candidate_evidence,
      status: if(missing == [], do: :ready, else: :open),
      release_candidate_evidence_complete?: missing == [],
      whole_project_complete?: false,
      allowed_wording: @allowed_wording,
      required_blocked_claims: @required_blocked_claims,
      open_hardware_gate_ids: open_gate_ids,
      persistence_lifecycle: persistence_lifecycle,
      lifecycle_review: lifecycle_review,
      ios_parity_review: ios_parity_review,
      full_resolution_review: full_resolution_review,
      known_good_transport_review: known_good_transport_review,
      multi_hop_review: multi_hop_review,
      routing_review: routing_review,
      security_review: security_review,
      ux_review: ux_review,
      hardware_attachments: hardware_attachments,
      operator_notes: operator_notes,
      missing: missing,
      notes: [
        "Ready evidence supports only the advert-only local release boundary.",
        "This review does not convert open hardware gates into passed gates.",
        "Whole-project completion remains blocked while readiness open items remain."
      ]
    }
  end

  @spec json_review(map()) :: map()
  def json_review(input) do
    input
    |> review()
    |> JSON.encode!()
    |> JSON.decode!()
  end

  @spec template_input() :: map()
  def template_input do
    %{
      "required_blocked_claims" => Enum.map(@required_blocked_claims, &Atom.to_string/1),
      "readiness_manifest_path" => "",
      "release_manifest_path" => "",
      "recent_evidence_inventory_path" => "",
      "completion_audit_path" => "",
      "completion_audit_plain_text_path" => "",
      "focused_remaining_items_audit_path" => "",
      "focused_remaining_items_plain_text_path" => "",
      "direct_full_mx_aux_validation_checklist_path" => "",
      "upstream_patch_maintainer_handoff_path" => "",
      "completion_blocker_matrix_path" => "",
      "advert_gossip_audit_path" => "",
      "persistence_lifecycle_plan_path" => "",
      "persistence_lifecycle" => %{
        "plan_path" => "",
        "plan_version" => 1,
        "boundary" => Atom.to_string(@persistence_lifecycle_boundary),
        "current_default_mode" => "memory_only",
        "opt_in_durable_snapshots_available?" => false,
        "production_default_persistence_allowed?" => false,
        "default_lifecycle_claim_allowed?" => false,
        "gate_count" => 0,
        "blocked_gate_count" => 0
      },
      "lifecycle_review_path" => "",
      "lifecycle_review" => %{
        "review_path" => "",
        "review_version" => 1,
        "boundary" => Atom.to_string(@lifecycle_review_boundary),
        "status" => "",
        "lifecycle_hardware_evidence_complete?" => false,
        "android_foreground_service_claim_allowed?" => false,
        "android_background_ble_claim_allowed?" => false,
        "ios_background_claim_allowed?" => false,
        "background_ble_claim_allowed?" => false,
        "restart_claim_allowed?" => false,
        "scheduled_retry_claim_allowed?" => false,
        "background_gossip_claim_allowed?" => false,
        "delivery_claim_allowed?" => false
      },
      "ios_parity_review_path" => "",
      "ios_parity_review" => %{
        "review_path" => "",
        "review_version" => 1,
        "boundary" => Atom.to_string(@ios_parity_review_boundary),
        "status" => "",
        "ios_hardware_evidence_complete?" => false,
        "ios_participation_claim_allowed?" => false,
        "ios_hardware_claim_allowed?" => false,
        "ios_legacy_beacon_observe_claim_allowed?" => false,
        "ios_legacy_beacon_gossip_claim_allowed?" => false,
        "ios_full_envelope_advert_claim_allowed?" => false,
        "ios_background_ble_claim_allowed?" => false,
        "ios_parity_claim_allowed?" => false
      },
      "full_resolution_review_path" => "",
      "full_resolution_review" => %{
        "review_path" => "",
        "review_version" => 1,
        "boundary" => Atom.to_string(@full_resolution_review_boundary),
        "status" => "",
        "full_resolution_transport_evidence_complete?" => false,
        "real_fetch_transport_validated?" => false,
        "full_message_resolution_claim_allowed?" => false,
        "known_good_transport_claim_allowed?" => false,
        "gatt_fetch_success_claim_allowed?" => false,
        "message_delivery_claim_allowed?" => false,
        "trusted_message_claim_allowed?" => false
      },
      "known_good_transport_review_path" => "",
      "known_good_transport_review" => %{
        "review_path" => "",
        "review_version" => 1,
        "boundary" => Atom.to_string(@known_good_transport_review_boundary),
        "status" => "",
        "known_good_transport_evidence_complete?" => false,
        "known_good_transport_claim_allowed?" => false,
        "gatt_fetch_success_claim_allowed?" => false,
        "full_message_resolution_claim_allowed?" => false,
        "message_delivery_claim_allowed?" => false
      },
      "multi_hop_review_path" => "",
      "multi_hop_review" => %{
        "review_path" => "",
        "review_version" => 1,
        "boundary" => Atom.to_string(@multi_hop_review_boundary),
        "status" => "",
        "multi_hop_hardware_evidence_complete?" => false,
        "multi_hop_physical_proof_present?" => false,
        "multi_hop_hardware_gossip_claim_allowed?" => false,
        "routed_delivery_claim_allowed?" => false,
        "guaranteed_delivery_claim_allowed?" => false,
        "trusted_delivery_claim_allowed?" => false,
        "background_operation_claim_allowed?" => false
      },
      "security_review_path" => "",
      "security_review" => %{
        "review_path" => "",
        "review_version" => 1,
        "boundary" => Atom.to_string(@security_review_boundary),
        "status" => "",
        "security_release_evidence_complete?" => false,
        "authenticated_peer_identity_claim_allowed?" => false,
        "authenticated_message_claim_allowed?" => false,
        "trusted_message_claim_allowed?" => false,
        "trusted_delivery_claim_allowed?" => false
      },
      "routing_review_path" => "",
      "routing_review" => %{
        "review_path" => "",
        "review_version" => 1,
        "boundary" => Atom.to_string(@routing_review_boundary),
        "status" => "",
        "production_routing_evidence_complete?" => false,
        "route_table_claim_allowed?" => false,
        "route_selection_claim_allowed?" => false,
        "forwarding_claim_allowed?" => false,
        "routed_delivery_claim_allowed?" => false,
        "guaranteed_delivery_claim_allowed?" => false,
        "multi_hop_hardware_claim_allowed?" => false
      },
      "ux_review_path" => "",
      "ux_review" => %{
        "review_path" => "",
        "review_version" => 1,
        "boundary" => Atom.to_string(@ux_review_boundary),
        "status" => "",
        "on_device_ux_evidence_complete?" => false,
        "production_ux_claim_allowed?" => false,
        "delivery_claim_allowed?" => false,
        "trusted_delivery_claim_allowed?" => false,
        "routing_claim_allowed?" => false,
        "target_device_count" => 0,
        "all_target_devices_have_state_coverage?" => false,
        "all_target_devices_have_interaction_coverage?" => false,
        "all_target_devices_have_selected_detail_coverage?" => false,
        "all_target_devices_have_selected_detail_copy_anchors?" => false,
        "all_target_devices_copy_reviewed?" => false,
        "all_target_devices_density_reviewed?" => false
      },
      "hardware_attachments" => [
        %{
          "device_model" => "",
          "os_or_api_version" => "",
          "role" => "",
          "command_or_harness" => "",
          "summary_path" => "",
          "raw_log_path" => "",
          "gate_ids" => [],
          "evidence_types_by_gate" =>
            @required_gate_evidence_types
            |> Map.new(fn {gate_id, evidence_type} ->
              {Atom.to_string(gate_id), Atom.to_string(evidence_type)}
            end)
        }
      ],
      "operator_notes" => %{
        "notes_path" => "",
        "allowed_wording" => @allowed_wording,
        "blocked_claims_called_out" => [],
        "open_hardware_gate_ids_called_out" => [],
        "readiness_manifest_path" => "",
        "completion_audit_path" => "",
        "completion_audit_plain_text_path" => "",
        "focused_remaining_items_audit_path" => "",
        "focused_remaining_items_plain_text_path" => "",
        "direct_full_mx_aux_validation_checklist_path" => "",
        "upstream_patch_maintainer_handoff_path" => "",
        "completion_blocker_matrix_path" => "",
        "release_manifest_path" => "",
        "recent_evidence_inventory_path" => "",
        "persistence_lifecycle_plan_path" => "",
        "lifecycle_review_path" => "",
        "ios_parity_review_path" => "",
        "full_resolution_review_path" => "",
        "known_good_transport_review_path" => "",
        "multi_hop_review_path" => "",
        "routing_review_path" => "",
        "security_review_path" => "",
        "ux_review_path" => ""
      }
    }
  end

  defp missing_required_paths(missing, input) do
    Enum.reduce(@required_paths, missing, fn field, acc ->
      if present?(get_field(input, field)) do
        acc
      else
        ["Missing #{field}." | acc]
      end
    end)
  end

  defp malformed_required_paths(missing, input) do
    Enum.reduce(@required_paths, missing, fn field, acc ->
      value = get_field(input, field)

      if is_nil(value) or is_binary(value) do
        acc
      else
        ["#{field} must be a string." | acc]
      end
    end)
  end

  defp non_trimmed_required_paths(missing, input) do
    Enum.reduce(@required_paths, missing, fn field, acc ->
      value = get_field(input, field)

      if not is_binary(value) or value == String.trim(value) do
        acc
      else
        ["#{field} must not have leading or trailing whitespace." | acc]
      end
    end)
  end

  defp non_relative_required_paths(missing, input) do
    Enum.reduce(@required_paths, missing, fn field, acc ->
      value = get_field(input, field)

      if relative_artifact_path?(value) do
        acc
      else
        ["#{field} must be a relative artifact path." | acc]
      end
    end)
  end

  defp missing_persistence_lifecycle(missing, input, persistence_lifecycle) do
    missing
    |> maybe_missing(
      is_map(get_field(input, :persistence_lifecycle, nil)),
      "Missing persistence_lifecycle summary."
    )
    |> missing_persistence_lifecycle_required_fields(input)
    |> missing_persistence_lifecycle_path(input, persistence_lifecycle)
    |> maybe_missing(
      persistence_lifecycle.plan_version == 1,
      "Persistence lifecycle plan_version must be 1."
    )
    |> maybe_missing(
      persistence_lifecycle.boundary == @persistence_lifecycle_boundary,
      "Persistence lifecycle boundary must be production_default_local_inbox_persistence_plan."
    )
    |> maybe_missing(
      persistence_lifecycle.current_default_mode == :memory_only,
      "Persistence lifecycle current_default_mode must be memory_only."
    )
    |> maybe_missing(
      persistence_lifecycle.opt_in_durable_snapshots_available?,
      "Persistence lifecycle must keep opt-in durable snapshots available."
    )
    |> maybe_missing(
      persistence_lifecycle.production_default_persistence_allowed? == false,
      "Persistence lifecycle production_default_persistence_allowed? must remain false."
    )
    |> maybe_missing(
      persistence_lifecycle.default_lifecycle_claim_allowed? == false,
      "Persistence lifecycle default_lifecycle_claim_allowed? must remain false."
    )
    |> maybe_missing(
      persistence_lifecycle.gate_count > 0,
      "Persistence lifecycle gate_count must be greater than 0."
    )
    |> maybe_missing(
      persistence_lifecycle.blocked_gate_count == persistence_lifecycle.gate_count,
      "Persistence lifecycle blocked_gate_count must equal gate_count."
    )
  end

  defp missing_persistence_lifecycle_required_fields(missing, input) do
    persistence_input = get_field(input, :persistence_lifecycle, %{})

    [
      :plan_path,
      :plan_version,
      :boundary,
      :current_default_mode,
      :opt_in_durable_snapshots_available?,
      :production_default_persistence_allowed?,
      :default_lifecycle_claim_allowed?,
      :gate_count,
      :blocked_gate_count
    ]
    |> Enum.reduce(missing, fn field, acc ->
      if is_map(persistence_input) and has_field?(persistence_input, field) do
        acc
      else
        ["Persistence lifecycle missing #{field}." | acc]
      end
    end)
  end

  defp missing_persistence_lifecycle_path(missing, input, persistence_lifecycle) do
    expected_path = get_field(input, :persistence_lifecycle_plan_path)

    cond do
      not present?(persistence_lifecycle.plan_path) ->
        ["Persistence lifecycle missing plan_path." | missing]

      present?(expected_path) and persistence_lifecycle.plan_path != expected_path ->
        ["Persistence lifecycle plan_path must match persistence_lifecycle_plan_path." | missing]

      true ->
        missing
    end
  end

  defp missing_lifecycle_review(missing, input, lifecycle_review) do
    missing
    |> maybe_missing(
      is_map(get_field(input, :lifecycle_review, nil)),
      "Missing lifecycle_review summary."
    )
    |> missing_lifecycle_review_required_fields(input)
    |> missing_lifecycle_review_path(input, lifecycle_review)
    |> maybe_missing(
      lifecycle_review.review_version == 1,
      "Lifecycle review review_version must be 1."
    )
    |> maybe_missing(
      lifecycle_review.boundary == @lifecycle_review_boundary,
      "Lifecycle review boundary must be mobile_ble_lifecycle_hardware_evidence_review."
    )
    |> maybe_missing(
      lifecycle_review.status == :ready,
      "Lifecycle review status must be ready."
    )
    |> maybe_missing(
      lifecycle_review.lifecycle_hardware_evidence_complete?,
      "Lifecycle review lifecycle_hardware_evidence_complete? must be true."
    )
    |> maybe_missing(
      lifecycle_review.android_foreground_service_claim_allowed? == false,
      "Lifecycle review android_foreground_service_claim_allowed? must remain false."
    )
    |> maybe_missing(
      lifecycle_review.android_background_ble_claim_allowed? == false,
      "Lifecycle review android_background_ble_claim_allowed? must remain false."
    )
    |> maybe_missing(
      lifecycle_review.ios_background_claim_allowed? == false,
      "Lifecycle review ios_background_claim_allowed? must remain false."
    )
    |> maybe_missing(
      lifecycle_review.background_ble_claim_allowed? == false,
      "Lifecycle review background_ble_claim_allowed? must remain false."
    )
    |> maybe_missing(
      lifecycle_review.restart_claim_allowed? == false,
      "Lifecycle review restart_claim_allowed? must remain false."
    )
    |> maybe_missing(
      lifecycle_review.scheduled_retry_claim_allowed? == false,
      "Lifecycle review scheduled_retry_claim_allowed? must remain false."
    )
    |> maybe_missing(
      lifecycle_review.background_gossip_claim_allowed? == false,
      "Lifecycle review background_gossip_claim_allowed? must remain false."
    )
    |> maybe_missing(
      lifecycle_review.delivery_claim_allowed? == false,
      "Lifecycle review delivery_claim_allowed? must remain false."
    )
  end

  defp missing_lifecycle_review_required_fields(missing, input) do
    lifecycle_input = get_field(input, :lifecycle_review, %{})

    [
      :review_path,
      :review_version,
      :boundary,
      :status,
      :lifecycle_hardware_evidence_complete?,
      :android_foreground_service_claim_allowed?,
      :android_background_ble_claim_allowed?,
      :ios_background_claim_allowed?,
      :background_ble_claim_allowed?,
      :restart_claim_allowed?,
      :scheduled_retry_claim_allowed?,
      :background_gossip_claim_allowed?,
      :delivery_claim_allowed?
    ]
    |> Enum.reduce(missing, fn field, acc ->
      if is_map(lifecycle_input) and has_field?(lifecycle_input, field) do
        acc
      else
        ["Lifecycle review missing #{field}." | acc]
      end
    end)
  end

  defp missing_lifecycle_review_path(missing, input, lifecycle_review) do
    expected_path = get_field(input, :lifecycle_review_path)

    cond do
      not present?(lifecycle_review.review_path) ->
        ["Lifecycle review missing review_path." | missing]

      present?(expected_path) and lifecycle_review.review_path != expected_path ->
        ["Lifecycle review review_path must match lifecycle_review_path." | missing]

      true ->
        missing
    end
  end

  defp missing_ios_parity_review(missing, input, ios_parity_review) do
    missing
    |> maybe_missing(
      is_map(get_field(input, :ios_parity_review, nil)),
      "Missing ios_parity_review summary."
    )
    |> missing_ios_parity_review_required_fields(input)
    |> missing_ios_parity_review_path(input, ios_parity_review)
    |> maybe_missing(
      ios_parity_review.review_version == 1,
      "iOS parity review review_version must be 1."
    )
    |> maybe_missing(
      ios_parity_review.boundary == @ios_parity_review_boundary,
      "iOS parity review boundary must be ios_advert_only_hardware_evidence_review."
    )
    |> maybe_missing(
      ios_parity_review.status == :ready,
      "iOS parity review status must be ready."
    )
    |> maybe_missing(
      ios_parity_review.ios_hardware_evidence_complete?,
      "iOS parity review ios_hardware_evidence_complete? must be true."
    )
    |> maybe_missing(
      ios_parity_review.ios_participation_claim_allowed? == false,
      "iOS parity review ios_participation_claim_allowed? must remain false."
    )
    |> maybe_missing(
      ios_parity_review.ios_hardware_claim_allowed? == false,
      "iOS parity review ios_hardware_claim_allowed? must remain false."
    )
    |> maybe_missing(
      ios_parity_review.ios_legacy_beacon_observe_claim_allowed? == false,
      "iOS parity review ios_legacy_beacon_observe_claim_allowed? must remain false."
    )
    |> maybe_missing(
      ios_parity_review.ios_legacy_beacon_gossip_claim_allowed? == false,
      "iOS parity review ios_legacy_beacon_gossip_claim_allowed? must remain false."
    )
    |> maybe_missing(
      ios_parity_review.ios_full_envelope_advert_claim_allowed? == false,
      "iOS parity review ios_full_envelope_advert_claim_allowed? must remain false."
    )
    |> maybe_missing(
      ios_parity_review.ios_background_ble_claim_allowed? == false,
      "iOS parity review ios_background_ble_claim_allowed? must remain false."
    )
    |> maybe_missing(
      ios_parity_review.ios_parity_claim_allowed? == false,
      "iOS parity review ios_parity_claim_allowed? must remain false."
    )
  end

  defp missing_ios_parity_review_required_fields(missing, input) do
    ios_input = get_field(input, :ios_parity_review, %{})

    [
      :review_path,
      :review_version,
      :boundary,
      :status,
      :ios_hardware_evidence_complete?,
      :ios_participation_claim_allowed?,
      :ios_hardware_claim_allowed?,
      :ios_legacy_beacon_observe_claim_allowed?,
      :ios_legacy_beacon_gossip_claim_allowed?,
      :ios_full_envelope_advert_claim_allowed?,
      :ios_background_ble_claim_allowed?,
      :ios_parity_claim_allowed?
    ]
    |> Enum.reduce(missing, fn field, acc ->
      if is_map(ios_input) and has_field?(ios_input, field) do
        acc
      else
        ["iOS parity review missing #{field}." | acc]
      end
    end)
  end

  defp missing_ios_parity_review_path(missing, input, ios_parity_review) do
    expected_path = get_field(input, :ios_parity_review_path)

    cond do
      not present?(ios_parity_review.review_path) ->
        ["iOS parity review missing review_path." | missing]

      present?(expected_path) and ios_parity_review.review_path != expected_path ->
        ["iOS parity review review_path must match ios_parity_review_path." | missing]

      true ->
        missing
    end
  end

  defp missing_full_resolution_review(missing, input, full_resolution_review) do
    missing
    |> maybe_missing(
      is_map(get_field(input, :full_resolution_review, nil)),
      "Missing full_resolution_review summary."
    )
    |> missing_full_resolution_review_required_fields(input)
    |> missing_full_resolution_review_path(input, full_resolution_review)
    |> maybe_missing(
      full_resolution_review.review_version == 1,
      "Full-resolution review review_version must be 1."
    )
    |> maybe_missing(
      full_resolution_review.boundary == @full_resolution_review_boundary,
      "Full-resolution review boundary must be full_message_resolution_transport_evidence_review."
    )
    |> maybe_missing(
      full_resolution_review.status == :ready,
      "Full-resolution review status must be ready."
    )
    |> maybe_missing(
      full_resolution_review.full_resolution_transport_evidence_complete?,
      "Full-resolution review full_resolution_transport_evidence_complete? must be true."
    )
    |> maybe_missing(
      full_resolution_review.real_fetch_transport_validated? == false,
      "Full-resolution review real_fetch_transport_validated? must remain false."
    )
    |> maybe_missing(
      full_resolution_review.full_message_resolution_claim_allowed? == false,
      "Full-resolution review full_message_resolution_claim_allowed? must remain false."
    )
    |> maybe_missing(
      full_resolution_review.known_good_transport_claim_allowed? == false,
      "Full-resolution review known_good_transport_claim_allowed? must remain false."
    )
    |> maybe_missing(
      full_resolution_review.gatt_fetch_success_claim_allowed? == false,
      "Full-resolution review gatt_fetch_success_claim_allowed? must remain false."
    )
    |> maybe_missing(
      full_resolution_review.message_delivery_claim_allowed? == false,
      "Full-resolution review message_delivery_claim_allowed? must remain false."
    )
    |> maybe_missing(
      full_resolution_review.trusted_message_claim_allowed? == false,
      "Full-resolution review trusted_message_claim_allowed? must remain false."
    )
  end

  defp missing_full_resolution_review_required_fields(missing, input) do
    full_resolution_input = get_field(input, :full_resolution_review, %{})

    [
      :review_path,
      :review_version,
      :boundary,
      :status,
      :full_resolution_transport_evidence_complete?,
      :real_fetch_transport_validated?,
      :full_message_resolution_claim_allowed?,
      :known_good_transport_claim_allowed?,
      :gatt_fetch_success_claim_allowed?,
      :message_delivery_claim_allowed?,
      :trusted_message_claim_allowed?
    ]
    |> Enum.reduce(missing, fn field, acc ->
      if is_map(full_resolution_input) and has_field?(full_resolution_input, field) do
        acc
      else
        ["Full-resolution review missing #{field}." | acc]
      end
    end)
  end

  defp missing_full_resolution_review_path(missing, input, full_resolution_review) do
    expected_path = get_field(input, :full_resolution_review_path)

    cond do
      not present?(full_resolution_review.review_path) ->
        ["Full-resolution review missing review_path." | missing]

      present?(expected_path) and full_resolution_review.review_path != expected_path ->
        [
          "Full-resolution review review_path must match full_resolution_review_path."
          | missing
        ]

      true ->
        missing
    end
  end

  defp missing_known_good_transport_review(missing, input, known_good_transport_review) do
    missing
    |> maybe_missing(
      is_map(get_field(input, :known_good_transport_review, nil)),
      "Missing known_good_transport_review summary."
    )
    |> missing_known_good_transport_review_required_fields(input)
    |> missing_known_good_transport_review_path(input, known_good_transport_review)
    |> maybe_missing(
      known_good_transport_review.review_version == 1,
      "Known-good transport review review_version must be 1."
    )
    |> maybe_missing(
      known_good_transport_review.boundary == @known_good_transport_review_boundary,
      "Known-good transport review boundary must be known_good_transport_evidence_review."
    )
    |> maybe_missing(
      known_good_transport_review.status == :ready,
      "Known-good transport review status must be ready."
    )
    |> maybe_missing(
      known_good_transport_review.known_good_transport_evidence_complete?,
      "Known-good transport review known_good_transport_evidence_complete? must be true."
    )
    |> maybe_missing(
      known_good_transport_review.known_good_transport_claim_allowed? == false,
      "Known-good transport review known_good_transport_claim_allowed? must remain false."
    )
    |> maybe_missing(
      known_good_transport_review.gatt_fetch_success_claim_allowed? == false,
      "Known-good transport review gatt_fetch_success_claim_allowed? must remain false."
    )
    |> maybe_missing(
      known_good_transport_review.full_message_resolution_claim_allowed? == false,
      "Known-good transport review full_message_resolution_claim_allowed? must remain false."
    )
    |> maybe_missing(
      known_good_transport_review.message_delivery_claim_allowed? == false,
      "Known-good transport review message_delivery_claim_allowed? must remain false."
    )
  end

  defp missing_known_good_transport_review_required_fields(missing, input) do
    transport_input = get_field(input, :known_good_transport_review, %{})

    [
      :review_path,
      :review_version,
      :boundary,
      :status,
      :known_good_transport_evidence_complete?,
      :known_good_transport_claim_allowed?,
      :gatt_fetch_success_claim_allowed?,
      :full_message_resolution_claim_allowed?,
      :message_delivery_claim_allowed?
    ]
    |> Enum.reduce(missing, fn field, acc ->
      if is_map(transport_input) and has_field?(transport_input, field) do
        acc
      else
        ["Known-good transport review missing #{field}." | acc]
      end
    end)
  end

  defp missing_known_good_transport_review_path(missing, input, known_good_transport_review) do
    expected_path = get_field(input, :known_good_transport_review_path)

    cond do
      not present?(known_good_transport_review.review_path) ->
        ["Known-good transport review missing review_path." | missing]

      present?(expected_path) and known_good_transport_review.review_path != expected_path ->
        [
          "Known-good transport review review_path must match known_good_transport_review_path."
          | missing
        ]

      true ->
        missing
    end
  end

  defp missing_multi_hop_review(missing, input, multi_hop_review) do
    missing
    |> maybe_missing(
      is_map(get_field(input, :multi_hop_review, nil)),
      "Missing multi_hop_review summary."
    )
    |> missing_multi_hop_review_required_fields(input)
    |> missing_multi_hop_review_path(input, multi_hop_review)
    |> maybe_missing(
      multi_hop_review.review_version == 1,
      "Multi-hop review review_version must be 1."
    )
    |> maybe_missing(
      multi_hop_review.boundary == @multi_hop_review_boundary,
      "Multi-hop review boundary must be multi_hop_hardware_evidence_review."
    )
    |> maybe_missing(multi_hop_review.status == :ready, "Multi-hop review status must be ready.")
    |> maybe_missing(
      multi_hop_review.multi_hop_hardware_evidence_complete?,
      "Multi-hop review multi_hop_hardware_evidence_complete? must be true."
    )
    |> maybe_missing(
      multi_hop_review.multi_hop_physical_proof_present? == false,
      "Multi-hop review multi_hop_physical_proof_present? must remain false."
    )
    |> maybe_missing(
      multi_hop_review.multi_hop_hardware_gossip_claim_allowed? == false,
      "Multi-hop review multi_hop_hardware_gossip_claim_allowed? must remain false."
    )
    |> maybe_missing(
      multi_hop_review.routed_delivery_claim_allowed? == false,
      "Multi-hop review routed_delivery_claim_allowed? must remain false."
    )
    |> maybe_missing(
      multi_hop_review.guaranteed_delivery_claim_allowed? == false,
      "Multi-hop review guaranteed_delivery_claim_allowed? must remain false."
    )
    |> maybe_missing(
      multi_hop_review.trusted_delivery_claim_allowed? == false,
      "Multi-hop review trusted_delivery_claim_allowed? must remain false."
    )
    |> maybe_missing(
      multi_hop_review.background_operation_claim_allowed? == false,
      "Multi-hop review background_operation_claim_allowed? must remain false."
    )
  end

  defp missing_multi_hop_review_required_fields(missing, input) do
    multi_hop_input = get_field(input, :multi_hop_review, %{})

    [
      :review_path,
      :review_version,
      :boundary,
      :status,
      :multi_hop_hardware_evidence_complete?,
      :multi_hop_physical_proof_present?,
      :multi_hop_hardware_gossip_claim_allowed?,
      :routed_delivery_claim_allowed?,
      :guaranteed_delivery_claim_allowed?,
      :trusted_delivery_claim_allowed?,
      :background_operation_claim_allowed?
    ]
    |> Enum.reduce(missing, fn field, acc ->
      if is_map(multi_hop_input) and has_field?(multi_hop_input, field) do
        acc
      else
        ["Multi-hop review missing #{field}." | acc]
      end
    end)
  end

  defp missing_multi_hop_review_path(missing, input, multi_hop_review) do
    expected_path = get_field(input, :multi_hop_review_path)

    cond do
      not present?(multi_hop_review.review_path) ->
        ["Multi-hop review missing review_path." | missing]

      present?(expected_path) and multi_hop_review.review_path != expected_path ->
        ["Multi-hop review review_path must match multi_hop_review_path." | missing]

      true ->
        missing
    end
  end

  defp missing_ux_review(missing, input, ux_review) do
    missing
    |> maybe_missing(
      is_map(get_field(input, :ux_review, nil)),
      "Missing ux_review summary."
    )
    |> missing_ux_review_required_fields(input)
    |> missing_ux_review_path(input, ux_review)
    |> maybe_missing(ux_review.review_version == 1, "UX review review_version must be 1.")
    |> maybe_missing(
      ux_review.boundary == @ux_review_boundary,
      "UX review boundary must be nearby_messages_on_device_ux_evidence."
    )
    |> maybe_missing(ux_review.status == :ready, "UX review status must be ready.")
    |> maybe_missing(
      ux_review.on_device_ux_evidence_complete?,
      "UX review on_device_ux_evidence_complete? must be true."
    )
    |> maybe_missing(
      ux_review.production_ux_claim_allowed? == false,
      "UX review production_ux_claim_allowed? must remain false."
    )
    |> maybe_missing(
      ux_review.delivery_claim_allowed? == false,
      "UX review delivery_claim_allowed? must remain false."
    )
    |> maybe_missing(
      ux_review.trusted_delivery_claim_allowed? == false,
      "UX review trusted_delivery_claim_allowed? must remain false."
    )
    |> maybe_missing(
      ux_review.routing_claim_allowed? == false,
      "UX review routing_claim_allowed? must remain false."
    )
    |> maybe_missing(
      ux_review.target_device_count > 0,
      "UX review target_device_count must be greater than 0."
    )
    |> maybe_missing(
      ux_review.all_target_devices_have_state_coverage?,
      "UX review missing state coverage."
    )
    |> maybe_missing(
      ux_review.all_target_devices_have_interaction_coverage?,
      "UX review missing interaction coverage."
    )
    |> maybe_missing(
      ux_review.all_target_devices_have_selected_detail_coverage?,
      "UX review missing selected detail coverage."
    )
    |> maybe_missing(
      ux_review.all_target_devices_have_selected_detail_copy_anchors?,
      "UX review missing selected detail limitation_copy, next_action_copy, and blocked_claim_copy coverage."
    )
    |> maybe_missing(
      ux_review.all_target_devices_copy_reviewed?,
      "UX review missing copy review coverage."
    )
    |> maybe_missing(
      ux_review.all_target_devices_density_reviewed?,
      "UX review missing density review coverage."
    )
  end

  defp missing_security_review(missing, input, security_review) do
    missing
    |> maybe_missing(
      is_map(get_field(input, :security_review, nil)),
      "Missing security_review summary."
    )
    |> missing_security_review_required_fields(input)
    |> missing_security_review_path(input, security_review)
    |> maybe_missing(
      security_review.review_version == 1,
      "Security review review_version must be 1."
    )
    |> maybe_missing(
      security_review.boundary == @security_review_boundary,
      "Security review boundary must be local_security_release_evidence_review."
    )
    |> maybe_missing(security_review.status == :ready, "Security review status must be ready.")
    |> maybe_missing(
      security_review.security_release_evidence_complete?,
      "Security review security_release_evidence_complete? must be true."
    )
    |> maybe_missing(
      security_review.authenticated_peer_identity_claim_allowed? == false,
      "Security review authenticated_peer_identity_claim_allowed? must remain false."
    )
    |> maybe_missing(
      security_review.authenticated_message_claim_allowed? == false,
      "Security review authenticated_message_claim_allowed? must remain false."
    )
    |> maybe_missing(
      security_review.trusted_message_claim_allowed? == false,
      "Security review trusted_message_claim_allowed? must remain false."
    )
    |> maybe_missing(
      security_review.trusted_delivery_claim_allowed? == false,
      "Security review trusted_delivery_claim_allowed? must remain false."
    )
  end

  defp missing_routing_review(missing, input, routing_review) do
    missing
    |> maybe_missing(
      is_map(get_field(input, :routing_review, nil)),
      "Missing routing_review summary."
    )
    |> missing_routing_review_required_fields(input)
    |> missing_routing_review_path(input, routing_review)
    |> maybe_missing(
      routing_review.review_version == 1,
      "Routing review review_version must be 1."
    )
    |> maybe_missing(
      routing_review.boundary == @routing_review_boundary,
      "Routing review boundary must be production_routing_evidence_review."
    )
    |> maybe_missing(routing_review.status == :ready, "Routing review status must be ready.")
    |> maybe_missing(
      routing_review.production_routing_evidence_complete?,
      "Routing review production_routing_evidence_complete? must be true."
    )
    |> maybe_missing(
      routing_review.route_table_claim_allowed? == false,
      "Routing review route_table_claim_allowed? must remain false."
    )
    |> maybe_missing(
      routing_review.route_selection_claim_allowed? == false,
      "Routing review route_selection_claim_allowed? must remain false."
    )
    |> maybe_missing(
      routing_review.forwarding_claim_allowed? == false,
      "Routing review forwarding_claim_allowed? must remain false."
    )
    |> maybe_missing(
      routing_review.routed_delivery_claim_allowed? == false,
      "Routing review routed_delivery_claim_allowed? must remain false."
    )
    |> maybe_missing(
      routing_review.guaranteed_delivery_claim_allowed? == false,
      "Routing review guaranteed_delivery_claim_allowed? must remain false."
    )
    |> maybe_missing(
      routing_review.multi_hop_hardware_claim_allowed? == false,
      "Routing review multi_hop_hardware_claim_allowed? must remain false."
    )
  end

  defp missing_routing_review_required_fields(missing, input) do
    routing_input = get_field(input, :routing_review, %{})

    [
      :review_path,
      :review_version,
      :boundary,
      :status,
      :production_routing_evidence_complete?,
      :route_table_claim_allowed?,
      :route_selection_claim_allowed?,
      :forwarding_claim_allowed?,
      :routed_delivery_claim_allowed?,
      :guaranteed_delivery_claim_allowed?,
      :multi_hop_hardware_claim_allowed?
    ]
    |> Enum.reduce(missing, fn field, acc ->
      if is_map(routing_input) and has_field?(routing_input, field) do
        acc
      else
        ["Routing review missing #{field}." | acc]
      end
    end)
  end

  defp missing_routing_review_path(missing, input, routing_review) do
    expected_path = get_field(input, :routing_review_path)

    cond do
      not present?(routing_review.review_path) ->
        ["Routing review missing review_path." | missing]

      present?(expected_path) and routing_review.review_path != expected_path ->
        ["Routing review review_path must match routing_review_path." | missing]

      true ->
        missing
    end
  end

  defp missing_security_review_required_fields(missing, input) do
    security_input = get_field(input, :security_review, %{})

    [
      :review_path,
      :review_version,
      :boundary,
      :status,
      :security_release_evidence_complete?,
      :authenticated_peer_identity_claim_allowed?,
      :authenticated_message_claim_allowed?,
      :trusted_message_claim_allowed?,
      :trusted_delivery_claim_allowed?
    ]
    |> Enum.reduce(missing, fn field, acc ->
      if is_map(security_input) and has_field?(security_input, field) do
        acc
      else
        ["Security review missing #{field}." | acc]
      end
    end)
  end

  defp missing_security_review_path(missing, input, security_review) do
    expected_path = get_field(input, :security_review_path)

    cond do
      not present?(security_review.review_path) ->
        ["Security review missing review_path." | missing]

      present?(expected_path) and security_review.review_path != expected_path ->
        ["Security review review_path must match security_review_path." | missing]

      true ->
        missing
    end
  end

  defp missing_ux_review_required_fields(missing, input) do
    ux_review_input = get_field(input, :ux_review, %{})

    [
      :review_version,
      :boundary,
      :on_device_ux_evidence_complete?,
      :production_ux_claim_allowed?,
      :delivery_claim_allowed?,
      :trusted_delivery_claim_allowed?,
      :routing_claim_allowed?,
      :all_target_devices_have_selected_detail_copy_anchors?
    ]
    |> Enum.reduce(missing, fn field, acc ->
      if is_map(ux_review_input) and has_field?(ux_review_input, field) do
        acc
      else
        ["UX review missing #{field}." | acc]
      end
    end)
  end

  defp missing_ux_review_path(missing, input, ux_review) do
    expected_path = get_field(input, :ux_review_path)

    cond do
      not present?(ux_review.review_path) ->
        ["UX review missing review_path." | missing]

      present?(expected_path) and ux_review.review_path != expected_path ->
        ["UX review review_path must match ux_review_path." | missing]

      true ->
        missing
    end
  end

  defp missing_hardware_attachments(missing, []),
    do: ["Missing at least one hardware attachment." | missing]

  defp missing_hardware_attachments(missing, attachments) do
    attachments
    |> Enum.with_index(1)
    |> Enum.reduce(missing, fn {attachment, index}, acc ->
      []
      |> missing_attachment_field(attachment, index, :device_model)
      |> missing_attachment_field(attachment, index, :os_or_api_version)
      |> missing_attachment_field(attachment, index, :role)
      |> missing_attachment_field(attachment, index, :command_or_harness)
      |> missing_attachment_field(attachment, index, :summary_path)
      |> malformed_attachment_string_field(attachment, index, :summary_path)
      |> non_trimmed_attachment_path(attachment, index, :summary_path)
      |> non_relative_attachment_path(attachment, index, :summary_path)
      |> missing_attachment_field(attachment, index, :raw_log_path)
      |> malformed_attachment_string_field(attachment, index, :raw_log_path)
      |> non_trimmed_attachment_path(attachment, index, :raw_log_path)
      |> non_relative_attachment_path(attachment, index, :raw_log_path)
      |> maybe_missing(
        attachment.gate_ids_container_valid?,
        "Hardware attachment #{index} gate_ids must be a list."
      )
      |> maybe_missing(
        attachment.evidence_types_by_gate_container_valid?,
        "Hardware attachment #{index} evidence_types_by_gate must be an object."
      )
      |> missing_attachment_gates(attachment, index)
      |> missing_attachment_evidence_types(attachment, index)
      |> Kernel.++(acc)
    end)
  end

  defp missing_operator_notes(missing, input, notes, open_gate_ids) do
    missing
    |> missing_operator_field(notes, :notes_path)
    |> missing_operator_field(notes, :readiness_manifest_path)
    |> missing_operator_field(notes, :completion_audit_path)
    |> missing_operator_field(notes, :completion_audit_plain_text_path)
    |> missing_operator_field(notes, :focused_remaining_items_audit_path)
    |> missing_operator_field(notes, :focused_remaining_items_plain_text_path)
    |> missing_operator_field(notes, :direct_full_mx_aux_validation_checklist_path)
    |> missing_operator_field(notes, :upstream_patch_maintainer_handoff_path)
    |> missing_operator_field(notes, :completion_blocker_matrix_path)
    |> missing_operator_field(notes, :release_manifest_path)
    |> missing_operator_field(notes, :recent_evidence_inventory_path)
    |> missing_operator_field(notes, :persistence_lifecycle_plan_path)
    |> missing_operator_field(notes, :lifecycle_review_path)
    |> missing_operator_field(notes, :ios_parity_review_path)
    |> missing_operator_field(notes, :full_resolution_review_path)
    |> missing_operator_field(notes, :known_good_transport_review_path)
    |> missing_operator_field(notes, :multi_hop_review_path)
    |> missing_operator_field(notes, :routing_review_path)
    |> missing_operator_field(notes, :security_review_path)
    |> missing_operator_field(notes, :ux_review_path)
    |> malformed_operator_path_fields(notes)
    |> non_trimmed_operator_paths(notes)
    |> non_relative_operator_paths(notes)
    |> mismatched_operator_path(input, notes, :readiness_manifest_path)
    |> mismatched_operator_path(input, notes, :completion_audit_path)
    |> mismatched_operator_path(input, notes, :completion_audit_plain_text_path)
    |> mismatched_operator_path(input, notes, :focused_remaining_items_audit_path)
    |> mismatched_operator_path(input, notes, :focused_remaining_items_plain_text_path)
    |> mismatched_operator_path(input, notes, :direct_full_mx_aux_validation_checklist_path)
    |> mismatched_operator_path(input, notes, :upstream_patch_maintainer_handoff_path)
    |> mismatched_operator_path(input, notes, :completion_blocker_matrix_path)
    |> mismatched_operator_path(input, notes, :release_manifest_path)
    |> mismatched_operator_path(input, notes, :recent_evidence_inventory_path)
    |> mismatched_operator_path(input, notes, :persistence_lifecycle_plan_path)
    |> mismatched_operator_path(input, notes, :lifecycle_review_path)
    |> mismatched_operator_path(input, notes, :ios_parity_review_path)
    |> mismatched_operator_path(input, notes, :full_resolution_review_path)
    |> mismatched_operator_path(input, notes, :known_good_transport_review_path)
    |> mismatched_operator_path(input, notes, :multi_hop_review_path)
    |> mismatched_operator_path(input, notes, :routing_review_path)
    |> mismatched_operator_path(input, notes, :security_review_path)
    |> mismatched_operator_path(input, notes, :ux_review_path)
    |> missing_allowed_wording(notes)
    |> maybe_missing(
      notes.blocked_claims_called_out_container_valid?,
      "Operator notes blocked_claims_called_out must be a list."
    )
    |> maybe_missing(
      notes.open_hardware_gate_ids_called_out_container_valid?,
      "Operator notes open_hardware_gate_ids_called_out must be a list."
    )
    |> missing_blocked_claims(notes)
    |> missing_open_gate_callouts(notes, open_gate_ids)
  end

  defp missing_attachment_field(missing, attachment, index, field) do
    if present?(Map.fetch!(attachment, field)) do
      missing
    else
      ["Hardware attachment #{index} missing #{field}." | missing]
    end
  end

  defp malformed_attachment_string_field(missing, attachment, index, field) do
    value = Map.fetch!(attachment, field)

    if is_nil(value) or is_binary(value) do
      missing
    else
      ["Hardware attachment #{index} #{field} must be a string." | missing]
    end
  end

  defp non_trimmed_attachment_path(missing, attachment, index, field) do
    value = Map.fetch!(attachment, field)

    if not is_binary(value) or value == String.trim(value) do
      missing
    else
      [
        "Hardware attachment #{index} #{field} must not have leading or trailing whitespace."
        | missing
      ]
    end
  end

  defp non_relative_attachment_path(missing, attachment, index, field) do
    value = Map.fetch!(attachment, field)

    if relative_artifact_path?(value) do
      missing
    else
      ["Hardware attachment #{index} #{field} must be a relative artifact path." | missing]
    end
  end

  defp missing_attachment_gates(missing, attachment, index) do
    if attachment.gate_ids == [] do
      ["Hardware attachment #{index} missing gate_ids." | missing]
    else
      missing
    end
  end

  defp missing_attachment_evidence_types(missing, attachment, index) do
    Enum.reduce(attachment.gate_ids, missing, fn gate_id, acc ->
      case Map.fetch(@required_gate_evidence_types, gate_id) do
        {:ok, expected} ->
          case Map.get(attachment.evidence_types_by_gate, gate_id) do
            ^expected ->
              acc

            nil ->
              [
                "Hardware attachment #{index} gate #{gate_id} missing evidence_type #{expected}."
                | acc
              ]

            actual ->
              [
                "Hardware attachment #{index} gate #{gate_id} evidence_type must be #{expected}, got #{inspect(actual)}."
                | acc
              ]
          end

        :error ->
          ["Hardware attachment #{index} references unknown gate_id #{inspect(gate_id)}." | acc]
      end
    end)
  end

  defp missing_operator_field(missing, notes, field) do
    if present?(Map.fetch!(notes, field)) do
      missing
    else
      ["Operator notes missing #{field}." | missing]
    end
  end

  defp malformed_operator_path_fields(missing, notes) do
    Enum.reduce(@operator_note_path_fields, missing, fn field, acc ->
      value = Map.fetch!(notes, field)

      if is_nil(value) or is_binary(value) do
        acc
      else
        ["Operator notes #{field} must be a string." | acc]
      end
    end)
  end

  defp non_trimmed_operator_paths(missing, notes) do
    Enum.reduce(@operator_note_path_fields, missing, fn field, acc ->
      value = Map.fetch!(notes, field)

      if not is_binary(value) or value == String.trim(value) do
        acc
      else
        ["Operator notes #{field} must not have leading or trailing whitespace." | acc]
      end
    end)
  end

  defp non_relative_operator_paths(missing, notes) do
    Enum.reduce(@operator_note_path_fields, missing, fn field, acc ->
      value = Map.fetch!(notes, field)

      if relative_artifact_path?(value) do
        acc
      else
        ["Operator notes #{field} must be a relative artifact path." | acc]
      end
    end)
  end

  defp mismatched_operator_path(missing, input, notes, field) do
    expected_path = get_field(input, field)
    actual_path = Map.fetch!(notes, field)

    if present?(expected_path) and present?(actual_path) and actual_path != expected_path do
      ["Operator notes #{field} must match top-level #{field}." | missing]
    else
      missing
    end
  end

  defp missing_allowed_wording(missing, notes) do
    if notes.allowed_wording == @allowed_wording do
      missing
    else
      ["Operator notes must use the approved messages-seen-nearby wording." | missing]
    end
  end

  defp missing_blocked_claims(missing, notes) do
    missing_claims = @required_blocked_claims -- notes.blocked_claims_called_out

    if missing_claims == [] do
      missing
    else
      ["Operator notes missing blocked claim callouts: #{inspect(missing_claims)}." | missing]
    end
  end

  defp missing_open_gate_callouts(missing, notes, open_gate_ids) do
    missing_gates = open_gate_ids -- notes.open_hardware_gate_ids_called_out

    if missing_gates == [] do
      missing
    else
      ["Operator notes missing open hardware gate callouts: #{inspect(missing_gates)}." | missing]
    end
  end

  defp malformed_release_candidate_containers(
         missing,
         hardware_attachments_input,
         operator_notes_input
       ) do
    missing
    |> maybe_missing(is_list(hardware_attachments_input), "hardware_attachments must be a list.")
    |> maybe_missing(is_map(operator_notes_input), "operator_notes must be an object.")
  end

  defp hardware_attachments(values) when is_list(values),
    do: Enum.map(values, &hardware_attachment/1)

  defp hardware_attachments(_values), do: []

  defp hardware_attachment(%HardwareAttachment{} = attachment), do: attachment

  defp hardware_attachment(input) when is_map(input) do
    gate_ids = get_field(input, :gate_ids, [])
    evidence_types_by_gate = get_field(input, :evidence_types_by_gate, %{})

    struct!(HardwareAttachment, %{
      device_model: get_field(input, :device_model),
      os_or_api_version: get_field(input, :os_or_api_version),
      role: get_field(input, :role),
      command_or_harness: get_field(input, :command_or_harness),
      summary_path: get_field(input, :summary_path),
      raw_log_path: get_field(input, :raw_log_path),
      gate_ids: atom_list(gate_ids),
      evidence_types_by_gate: atom_map(evidence_types_by_gate),
      gate_ids_container_valid?: is_list(gate_ids),
      evidence_types_by_gate_container_valid?: is_map(evidence_types_by_gate)
    })
  end

  defp hardware_attachment(_input), do: hardware_attachment(%{})

  defp operator_notes(%OperatorNotes{} = notes), do: notes

  defp operator_notes(input) when is_map(input) do
    blocked_claims_called_out = get_field(input, :blocked_claims_called_out, [])
    open_hardware_gate_ids_called_out = get_field(input, :open_hardware_gate_ids_called_out, [])

    struct!(OperatorNotes, %{
      notes_path: get_field(input, :notes_path),
      allowed_wording: get_field(input, :allowed_wording),
      blocked_claims_called_out: atom_list(blocked_claims_called_out),
      open_hardware_gate_ids_called_out: atom_list(open_hardware_gate_ids_called_out),
      readiness_manifest_path: get_field(input, :readiness_manifest_path),
      completion_audit_path: get_field(input, :completion_audit_path),
      completion_audit_plain_text_path: get_field(input, :completion_audit_plain_text_path),
      focused_remaining_items_audit_path: get_field(input, :focused_remaining_items_audit_path),
      focused_remaining_items_plain_text_path:
        get_field(input, :focused_remaining_items_plain_text_path),
      direct_full_mx_aux_validation_checklist_path:
        get_field(input, :direct_full_mx_aux_validation_checklist_path),
      upstream_patch_maintainer_handoff_path:
        get_field(input, :upstream_patch_maintainer_handoff_path),
      completion_blocker_matrix_path: get_field(input, :completion_blocker_matrix_path),
      release_manifest_path: get_field(input, :release_manifest_path),
      recent_evidence_inventory_path: get_field(input, :recent_evidence_inventory_path),
      persistence_lifecycle_plan_path: get_field(input, :persistence_lifecycle_plan_path),
      lifecycle_review_path: get_field(input, :lifecycle_review_path),
      ios_parity_review_path: get_field(input, :ios_parity_review_path),
      full_resolution_review_path: get_field(input, :full_resolution_review_path),
      known_good_transport_review_path: get_field(input, :known_good_transport_review_path),
      multi_hop_review_path: get_field(input, :multi_hop_review_path),
      routing_review_path: get_field(input, :routing_review_path),
      security_review_path: get_field(input, :security_review_path),
      ux_review_path: get_field(input, :ux_review_path),
      blocked_claims_called_out_container_valid?: is_list(blocked_claims_called_out),
      open_hardware_gate_ids_called_out_container_valid?:
        is_list(open_hardware_gate_ids_called_out)
    })
  end

  defp operator_notes(_input), do: operator_notes(%{})

  defp persistence_lifecycle_summary(%PersistenceLifecycleSummary{} = summary), do: summary

  defp persistence_lifecycle_summary(input) when is_map(input) do
    struct!(PersistenceLifecycleSummary, %{
      plan_path: get_field(input, :plan_path),
      plan_version: integer_value(get_field(input, :plan_version, 0)),
      boundary: atom_value(get_field(input, :boundary)),
      current_default_mode: atom_value(get_field(input, :current_default_mode)),
      opt_in_durable_snapshots_available?:
        boolean_value(get_field(input, :opt_in_durable_snapshots_available?, false)),
      production_default_persistence_allowed?:
        boolean_value(get_field(input, :production_default_persistence_allowed?, false)),
      default_lifecycle_claim_allowed?:
        boolean_value(get_field(input, :default_lifecycle_claim_allowed?, false)),
      gate_count: integer_value(get_field(input, :gate_count, 0)),
      blocked_gate_count: integer_value(get_field(input, :blocked_gate_count, 0))
    })
  end

  defp persistence_lifecycle_summary(_input), do: persistence_lifecycle_summary(%{})

  defp lifecycle_review_summary(%LifecycleReviewSummary{} = summary), do: summary

  defp lifecycle_review_summary(input) when is_map(input) do
    struct!(LifecycleReviewSummary, %{
      review_path: get_field(input, :review_path),
      review_version: integer_value(get_field(input, :review_version, 0)),
      boundary: atom_value(get_field(input, :boundary)),
      status: atom_value(get_field(input, :status)),
      lifecycle_hardware_evidence_complete?:
        boolean_value(get_field(input, :lifecycle_hardware_evidence_complete?, false)),
      android_foreground_service_claim_allowed?:
        boolean_value(get_field(input, :android_foreground_service_claim_allowed?, false)),
      android_background_ble_claim_allowed?:
        boolean_value(get_field(input, :android_background_ble_claim_allowed?, false)),
      ios_background_claim_allowed?:
        boolean_value(get_field(input, :ios_background_claim_allowed?, false)),
      background_ble_claim_allowed?:
        boolean_value(get_field(input, :background_ble_claim_allowed?, false)),
      restart_claim_allowed?: boolean_value(get_field(input, :restart_claim_allowed?, false)),
      scheduled_retry_claim_allowed?:
        boolean_value(get_field(input, :scheduled_retry_claim_allowed?, false)),
      background_gossip_claim_allowed?:
        boolean_value(get_field(input, :background_gossip_claim_allowed?, false)),
      delivery_claim_allowed?: boolean_value(get_field(input, :delivery_claim_allowed?, false))
    })
  end

  defp lifecycle_review_summary(_input), do: lifecycle_review_summary(%{})

  defp full_resolution_review_summary(%FullResolutionReviewSummary{} = summary), do: summary

  defp full_resolution_review_summary(input) when is_map(input) do
    struct!(FullResolutionReviewSummary, %{
      review_path: get_field(input, :review_path),
      review_version: integer_value(get_field(input, :review_version, 0)),
      boundary: atom_value(get_field(input, :boundary)),
      status: atom_value(get_field(input, :status)),
      full_resolution_transport_evidence_complete?:
        boolean_value(get_field(input, :full_resolution_transport_evidence_complete?, false)),
      real_fetch_transport_validated?:
        boolean_value(get_field(input, :real_fetch_transport_validated?, false)),
      full_message_resolution_claim_allowed?:
        boolean_value(get_field(input, :full_message_resolution_claim_allowed?, false)),
      known_good_transport_claim_allowed?:
        boolean_value(get_field(input, :known_good_transport_claim_allowed?, false)),
      gatt_fetch_success_claim_allowed?:
        boolean_value(get_field(input, :gatt_fetch_success_claim_allowed?, false)),
      message_delivery_claim_allowed?:
        boolean_value(get_field(input, :message_delivery_claim_allowed?, false)),
      trusted_message_claim_allowed?:
        boolean_value(get_field(input, :trusted_message_claim_allowed?, false))
    })
  end

  defp full_resolution_review_summary(_input), do: full_resolution_review_summary(%{})

  defp known_good_transport_review_summary(%KnownGoodTransportReviewSummary{} = summary),
    do: summary

  defp known_good_transport_review_summary(input) when is_map(input) do
    struct!(KnownGoodTransportReviewSummary, %{
      review_path: get_field(input, :review_path),
      review_version: integer_value(get_field(input, :review_version, 0)),
      boundary: atom_value(get_field(input, :boundary)),
      status: atom_value(get_field(input, :status)),
      known_good_transport_evidence_complete?:
        boolean_value(get_field(input, :known_good_transport_evidence_complete?, false)),
      known_good_transport_claim_allowed?:
        boolean_value(get_field(input, :known_good_transport_claim_allowed?, false)),
      gatt_fetch_success_claim_allowed?:
        boolean_value(get_field(input, :gatt_fetch_success_claim_allowed?, false)),
      full_message_resolution_claim_allowed?:
        boolean_value(get_field(input, :full_message_resolution_claim_allowed?, false)),
      message_delivery_claim_allowed?:
        boolean_value(get_field(input, :message_delivery_claim_allowed?, false))
    })
  end

  defp known_good_transport_review_summary(_input),
    do: known_good_transport_review_summary(%{})

  defp multi_hop_review_summary(%MultiHopReviewSummary{} = summary), do: summary

  defp multi_hop_review_summary(input) when is_map(input) do
    struct!(MultiHopReviewSummary, %{
      review_path: get_field(input, :review_path),
      review_version: integer_value(get_field(input, :review_version, 0)),
      boundary: atom_value(get_field(input, :boundary)),
      status: atom_value(get_field(input, :status)),
      multi_hop_hardware_evidence_complete?:
        boolean_value(get_field(input, :multi_hop_hardware_evidence_complete?, false)),
      multi_hop_physical_proof_present?:
        boolean_value(get_field(input, :multi_hop_physical_proof_present?, false)),
      multi_hop_hardware_gossip_claim_allowed?:
        boolean_value(get_field(input, :multi_hop_hardware_gossip_claim_allowed?, false)),
      routed_delivery_claim_allowed?:
        boolean_value(get_field(input, :routed_delivery_claim_allowed?, false)),
      guaranteed_delivery_claim_allowed?:
        boolean_value(get_field(input, :guaranteed_delivery_claim_allowed?, false)),
      trusted_delivery_claim_allowed?:
        boolean_value(get_field(input, :trusted_delivery_claim_allowed?, false)),
      background_operation_claim_allowed?:
        boolean_value(get_field(input, :background_operation_claim_allowed?, false))
    })
  end

  defp multi_hop_review_summary(_input), do: multi_hop_review_summary(%{})

  defp ios_parity_review_summary(%IOSParityReviewSummary{} = summary), do: summary

  defp ios_parity_review_summary(input) when is_map(input) do
    struct!(IOSParityReviewSummary, %{
      review_path: get_field(input, :review_path),
      review_version: integer_value(get_field(input, :review_version, 0)),
      boundary: atom_value(get_field(input, :boundary)),
      status: atom_value(get_field(input, :status)),
      ios_hardware_evidence_complete?:
        boolean_value(get_field(input, :ios_hardware_evidence_complete?, false)),
      ios_participation_claim_allowed?:
        boolean_value(get_field(input, :ios_participation_claim_allowed?, false)),
      ios_hardware_claim_allowed?:
        boolean_value(get_field(input, :ios_hardware_claim_allowed?, false)),
      ios_legacy_beacon_observe_claim_allowed?:
        boolean_value(get_field(input, :ios_legacy_beacon_observe_claim_allowed?, false)),
      ios_legacy_beacon_gossip_claim_allowed?:
        boolean_value(get_field(input, :ios_legacy_beacon_gossip_claim_allowed?, false)),
      ios_full_envelope_advert_claim_allowed?:
        boolean_value(get_field(input, :ios_full_envelope_advert_claim_allowed?, false)),
      ios_background_ble_claim_allowed?:
        boolean_value(get_field(input, :ios_background_ble_claim_allowed?, false)),
      ios_parity_claim_allowed?:
        boolean_value(get_field(input, :ios_parity_claim_allowed?, false))
    })
  end

  defp ios_parity_review_summary(_input), do: ios_parity_review_summary(%{})

  defp security_review_summary(%SecurityReviewSummary{} = summary), do: summary

  defp security_review_summary(input) when is_map(input) do
    struct!(SecurityReviewSummary, %{
      review_path: get_field(input, :review_path),
      review_version: integer_value(get_field(input, :review_version, 0)),
      boundary: atom_value(get_field(input, :boundary)),
      status: atom_value(get_field(input, :status)),
      security_release_evidence_complete?:
        boolean_value(get_field(input, :security_release_evidence_complete?, false)),
      authenticated_peer_identity_claim_allowed?:
        boolean_value(get_field(input, :authenticated_peer_identity_claim_allowed?, false)),
      authenticated_message_claim_allowed?:
        boolean_value(get_field(input, :authenticated_message_claim_allowed?, false)),
      trusted_message_claim_allowed?:
        boolean_value(get_field(input, :trusted_message_claim_allowed?, false)),
      trusted_delivery_claim_allowed?:
        boolean_value(get_field(input, :trusted_delivery_claim_allowed?, false))
    })
  end

  defp security_review_summary(_input), do: security_review_summary(%{})

  defp routing_review_summary(%RoutingReviewSummary{} = summary), do: summary

  defp routing_review_summary(input) when is_map(input) do
    struct!(RoutingReviewSummary, %{
      review_path: get_field(input, :review_path),
      review_version: integer_value(get_field(input, :review_version, 0)),
      boundary: atom_value(get_field(input, :boundary)),
      status: atom_value(get_field(input, :status)),
      production_routing_evidence_complete?:
        boolean_value(get_field(input, :production_routing_evidence_complete?, false)),
      route_table_claim_allowed?:
        boolean_value(get_field(input, :route_table_claim_allowed?, false)),
      route_selection_claim_allowed?:
        boolean_value(get_field(input, :route_selection_claim_allowed?, false)),
      forwarding_claim_allowed?:
        boolean_value(get_field(input, :forwarding_claim_allowed?, false)),
      routed_delivery_claim_allowed?:
        boolean_value(get_field(input, :routed_delivery_claim_allowed?, false)),
      guaranteed_delivery_claim_allowed?:
        boolean_value(get_field(input, :guaranteed_delivery_claim_allowed?, false)),
      multi_hop_hardware_claim_allowed?:
        boolean_value(get_field(input, :multi_hop_hardware_claim_allowed?, false))
    })
  end

  defp routing_review_summary(_input), do: routing_review_summary(%{})

  defp ux_review_summary(%UxReviewSummary{} = summary), do: summary

  defp ux_review_summary(input) when is_map(input) do
    struct!(UxReviewSummary, %{
      review_path: get_field(input, :review_path),
      review_version: integer_value(get_field(input, :review_version, 0)),
      boundary: atom_value(get_field(input, :boundary)),
      status: atom_value(get_field(input, :status)),
      on_device_ux_evidence_complete?:
        boolean_value(get_field(input, :on_device_ux_evidence_complete?, false)),
      production_ux_claim_allowed?:
        boolean_value(get_field(input, :production_ux_claim_allowed?, false)),
      delivery_claim_allowed?: boolean_value(get_field(input, :delivery_claim_allowed?, false)),
      trusted_delivery_claim_allowed?:
        boolean_value(get_field(input, :trusted_delivery_claim_allowed?, false)),
      routing_claim_allowed?: boolean_value(get_field(input, :routing_claim_allowed?, false)),
      target_device_count: integer_value(get_field(input, :target_device_count, 0)),
      all_target_devices_have_state_coverage?:
        boolean_value(get_field(input, :all_target_devices_have_state_coverage?, false)),
      all_target_devices_have_interaction_coverage?:
        boolean_value(get_field(input, :all_target_devices_have_interaction_coverage?, false)),
      all_target_devices_have_selected_detail_coverage?:
        boolean_value(get_field(input, :all_target_devices_have_selected_detail_coverage?, false)),
      all_target_devices_have_selected_detail_copy_anchors?:
        boolean_value(
          get_field(input, :all_target_devices_have_selected_detail_copy_anchors?, false)
        ),
      all_target_devices_copy_reviewed?:
        boolean_value(get_field(input, :all_target_devices_copy_reviewed?, false)),
      all_target_devices_density_reviewed?:
        boolean_value(get_field(input, :all_target_devices_density_reviewed?, false))
    })
  end

  defp ux_review_summary(_input), do: ux_review_summary(%{})

  defp maybe_missing(missing, true, _message), do: missing
  defp maybe_missing(missing, false, message), do: [message | missing]

  defp has_field?(input, field) when is_atom(field) do
    Map.has_key?(input, field) or Map.has_key?(input, Atom.to_string(field))
  end

  defp get_field(input, field, default \\ nil) when is_atom(field) do
    Map.get(input, field, Map.get(input, Atom.to_string(field), default))
  end

  defp atom_list(values) when is_list(values), do: Enum.map(values, &atom_value/1)
  defp atom_list(_value), do: []

  defp atom_map(values) when is_map(values) do
    Map.new(values, fn {key, value} -> {atom_value(key), atom_value(value)} end)
  end

  defp atom_map(_value), do: %{}

  defp atom_value(value) when is_atom(value), do: value

  defp atom_value(value) when is_binary(value) do
    String.to_existing_atom(value)
  rescue
    ArgumentError -> value
  end

  defp atom_value(value), do: value

  defp integer_value(value) when is_integer(value) and value >= 0, do: value
  defp integer_value(_value), do: 0

  defp boolean_value(value) when is_boolean(value), do: value
  defp boolean_value(_value), do: false

  defp open_hardware_gate_ids do
    LocalReleaseEvidenceManifest.open_entries()
    |> Enum.map(& &1.gate_id)
  end

  defp relative_artifact_path?(value) when is_binary(value) do
    trimmed = String.trim(value)

    present?(trimmed) and
      not String.match?(trimmed, ~r/^[A-Za-z]:[\\\/]/) and
      not String.starts_with?(trimmed, ["/", "\\\\", "~", "file:", "http:", "https:"]) and
      not String.contains?(trimmed, "..")
  end

  defp relative_artifact_path?(_value), do: true

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(value), do: not is_nil(value)
end
