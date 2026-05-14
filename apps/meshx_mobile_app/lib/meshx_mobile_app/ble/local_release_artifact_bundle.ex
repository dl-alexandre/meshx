defmodule MeshxMobileApp.BLE.LocalReleaseArtifactBundle do
  @moduledoc """
  Release-candidate artifact bundle checklist for advert-only local mesh.

  This is an operator-facing packaging contract. It records which files
  and attachments must be archived for a release candidate, and which
  claims each artifact is allowed to support. It does not generate files,
  inspect hardware, scan, advertise, fetch, route, persist, ACK, retry,
  encrypt, or run background work.
  """

  defmodule Artifact do
    @moduledoc false

    @derive {JSON.Encoder,
             only: [
               :id,
               :status,
               :path,
               :source,
               :purpose,
               :required_for,
               :acceptance_criteria,
               :blocked_claims
             ]}
    @enforce_keys [
      :id,
      :status,
      :path,
      :source,
      :purpose,
      :required_for,
      :acceptance_criteria,
      :blocked_claims
    ]
    defstruct @enforce_keys

    @type id ::
            :readiness_manifest
            | :release_manifest
            | :completion_audit_manifest
            | :completion_audit_plain_text_review
            | :completion_audit_standalone
            | :completion_blocker_matrix
            | :full_message_resolution_evidence_manifest
            | :full_resolution_transport_evidence_review
            | :known_good_transport_evidence_review
            | :ux_evidence_manifest
            | :ux_decision_scenario_plan
            | :ux_evidence_template
            | :ux_evidence_review
            | :ios_parity_evidence_manifest
            | :ios_parity_decision_scenario_plan
            | :ios_parity_operator_capture_plan
            | :ios_parity_hardware_evidence_review
            | :lifecycle_validation_plan
            | :lifecycle_evidence_manifest
            | :lifecycle_decision_scenario_plan
            | :lifecycle_hardware_evidence_review
            | :multi_hop_hardware_evidence_manifest
            | :multi_hop_hardware_evidence_review
            | :production_persistence_lifecycle_plan
            | :persistence_evidence_manifest
            | :production_persistence_evidence_review
            | :routing_validation_plan
            | :routing_evidence_manifest
            | :routing_decision_scenario_plan
            | :production_routing_evidence_review
            | :hardware_evidence_manifest
            | :recent_evidence_inventory
            | :security_validation_plan
            | :security_evidence_manifest
            | :security_decision_scenario_plan
            | :security_operator_capture_plan
            | :security_release_evidence_review
            | :advert_gossip_audit_output
            | :hardware_log_bundle
            | :release_operator_capture_plan
            | :operator_release_notes
    @type status :: :generated | :embedded | :operator_supplied_open | :open

    @type t :: %__MODULE__{
            id: id(),
            status: status(),
            path: binary(),
            source: binary(),
            purpose: binary(),
            required_for: [atom()],
            acceptance_criteria: [binary()],
            blocked_claims: [atom()]
          }
  end

  @spec artifacts() :: [Artifact.t()]
  def artifacts do
    [
      %Artifact{
        id: :readiness_manifest,
        status: :generated,
        path: "tmp/local-readiness.json",
        source:
          "mix meshx.mobile.local_readiness.audit --allow-open --out tmp/local-readiness.json",
        purpose: "Archive project-level blocked and partial items.",
        required_for: [:advert_only_local_release],
        acceptance_criteria: [
          "open_item_count remains visible.",
          "blocked and partial items are not removed from release notes."
        ],
        blocked_claims: [:whole_project_complete]
      },
      %Artifact{
        id: :release_manifest,
        status: :generated,
        path: "tmp/local-release.json",
        source: "mix meshx.mobile.local_release.manifest --json --out tmp/local-release.json",
        purpose: "Archive advert-only release boundary, policy gates, and wording constraints.",
        required_for: [:advert_only_local_release],
        acceptance_criteria: [
          "mode is advertisement_only_local_mesh.",
          "releasable_with_limitations? is true.",
          "whole_project_complete? is false."
        ],
        blocked_claims: [
          :guaranteed_delivery,
          :trusted_delivery,
          :routed_delivery,
          :background_operation,
          :ios_parity
        ]
      },
      %Artifact{
        id: :completion_audit_manifest,
        status: :embedded,
        path: "tmp/local-release.json#/completion_audit",
        source: "LocalReleaseManifest.snapshot().completion_audit",
        purpose: "Archive the whole-project completion claim gate.",
        required_for: [:completion_review],
        acceptance_criteria: [
          "completion_claim_allowed? is false while any blocker remains.",
          "Each objective item lists required artifacts and missing evidence."
        ],
        blocked_claims: [:whole_project_complete]
      },
      %Artifact{
        id: :completion_audit_standalone,
        status: :generated,
        path: "tmp/local-completion-audit.json",
        source:
          "mix meshx.mobile.local_completion.audit --allow-open --json --out tmp/local-completion-audit.json",
        purpose: "Archive the whole-project completion audit as a standalone release artifact.",
        required_for: [:completion_review, :release_planning],
        acceptance_criteria: [
          "completion_claim_allowed? is false while any blocker remains.",
          "Prompt artifact checklist maps every objective to required evidence and missing evidence.",
          "Prompt artifact checklist count and ordered objective IDs are visible in the plain-text audit summary.",
          "Required command gates remain visible for completion review."
        ],
        blocked_claims: [:whole_project_complete]
      },
      %Artifact{
        id: :completion_audit_plain_text_review,
        status: :generated,
        path: "tmp/local-completion-audit.txt",
        source:
          "mix meshx.mobile.local_completion.audit --allow-open | tee tmp/local-completion-audit.txt",
        purpose:
          "Review the plain-text whole-project completion audit summary before release acceptance.",
        required_for: [:completion_review, :operator_release_review],
        acceptance_criteria: [
          "The plain-text audit output is archived beside the JSON completion audit.",
          "OPEN_ITEMS 10 is printed.",
          "Every remaining objective is printed as OPEN_ITEM objective=... status=... missing=....",
          "The output keeps blocked and partial project areas visible without opening JSON."
        ],
        blocked_claims: [:whole_project_complete]
      },
      %Artifact{
        id: :completion_blocker_matrix,
        status: :generated,
        path: "tmp/local-completion-blocker-matrix.json",
        source:
          "mix meshx.mobile.local_completion.blocker_matrix --json --out tmp/local-completion-blocker-matrix.json",
        purpose: "Archive blocker classification for every remaining whole-project objective.",
        required_for: [:completion_review, :release_planning],
        acceptance_criteria: [
          "Hardware-blocked objectives remain separate from product-decision and release-evidence work.",
          "Items that can progress without new hardware are visible.",
          "Plain-text blocker matrix output lists HARDWARE_BLOCKED and NO_NEW_HARDWARE objective groups.",
          "completion_claim_allowed? remains false."
        ],
        blocked_claims: [:whole_project_complete, :hardware_complete, :release_complete]
      },
      %Artifact{
        id: :full_message_resolution_evidence_manifest,
        status: :generated,
        path: "tmp/local-full-resolution-evidence.json",
        source:
          "mix meshx.mobile.local_full_resolution.evidence --json --out tmp/local-full-resolution-evidence.json",
        purpose:
          "Archive BeaconRef resolution contracts and blocked real transport validation gates.",
        required_for: [:full_message_resolution_review, :known_good_transport_review],
        acceptance_criteria: [
          "real_fetch_transport_validated? remains false until hardware evidence exists.",
          "Fake/offline fetch remains contract evidence, not transport proof.",
          "LocalFetchTransportValidationPlan blocked gates remain visible."
        ],
        blocked_claims: [
          :full_message_resolution,
          :known_good_transport,
          :gatt_fetch_success,
          :message_delivery,
          :trusted_delivery,
          :routed_delivery,
          :whole_project_complete
        ]
      },
      %Artifact{
        id: :full_resolution_transport_evidence_template,
        status: :operator_supplied_open,
        path: "artifacts/local-ble/<run-id>/full-resolution/evidence.json",
        source:
          "mix meshx.mobile.local_full_resolution.transport_review --template --out artifacts/local-ble/<run-id>/full-resolution/evidence.json",
        purpose:
          "Generate incomplete full-message-resolution transport metadata before operator-supplied review.",
        required_for: [:full_message_resolution_review],
        acceptance_criteria: [
          "Template lists every full-message-resolution transport validation gate.",
          "Generated metadata remains incomplete until artifact paths, summaries, commands, and blocked-claim callouts are supplied.",
          "Template review keeps real fetch transport, full-message resolution, delivery, trust, routing, background delivery, and completion claims blocked."
        ],
        blocked_claims: [
          :full_message_resolution,
          :known_good_transport,
          :transport_validated,
          :gatt_fetch_success,
          :resolved_message,
          :message_delivery,
          :trusted_message,
          :trusted_delivery,
          :routed_delivery,
          :background_delivery,
          :guaranteed_delivery,
          :fake_success,
          :whole_project_complete
        ]
      },
      %Artifact{
        id: :full_resolution_transport_evidence_review,
        status: :operator_supplied_open,
        path: "tmp/local-full-resolution-transport-review.json",
        source:
          "mix meshx.mobile.local_full_resolution.transport_review --input artifacts/local-ble/<run-id>/full-resolution/evidence.json --json --out tmp/local-full-resolution-transport-review.json",
        purpose:
          "Review real transport evidence before accepting full beacon resolution wording.",
        required_for: [:full_message_resolution_review, :known_good_transport_review],
        acceptance_criteria: [
          "Current GATT blocker, candidate transport, standalone interop, constrained fetch, canonical replay, negative failure, and release linkage evidence are present.",
          "Blocked resolution, known-good transport, delivery, trust, routing, background, fake-success, and completion claims are called out.",
          "Beacon refs remain unresolved pointers until hardware evidence retrieves and replay-parses a matching MessageEnvelope."
        ],
        blocked_claims: [
          :full_message_resolution,
          :known_good_transport,
          :transport_validated,
          :gatt_fetch_success,
          :resolved_message,
          :message_delivery,
          :trusted_message,
          :trusted_delivery,
          :routed_delivery,
          :background_delivery,
          :guaranteed_delivery,
          :fake_success,
          :whole_project_complete
        ]
      },
      %Artifact{
        id: :known_good_transport_evidence_template,
        status: :operator_supplied_open,
        path: "artifacts/local-ble/<run-id>/transport/evidence.json",
        source:
          "mix meshx.mobile.local_known_good_transport.review --template --out artifacts/local-ble/<run-id>/transport/evidence.json",
        purpose:
          "Generate incomplete known-good transport evidence metadata before operator-supplied review.",
        required_for: [:known_good_transport_review],
        acceptance_criteria: [
          "Template lists every known-good transport validation gate.",
          "Generated metadata remains incomplete until artifact paths, summaries, commands, and blocked-claim callouts are supplied.",
          "Template review keeps known-good transport, GATT fetch, full-message resolution, delivery, and completion claims blocked."
        ],
        blocked_claims: [
          :known_good_transport,
          :transport_validated,
          :gatt_fetch_success,
          :full_message_resolution,
          :message_delivery,
          :trusted_delivery,
          :routed_delivery,
          :whole_project_complete
        ]
      },
      %Artifact{
        id: :known_good_transport_evidence_review,
        status: :operator_supplied_open,
        path: "tmp/local-known-good-transport-review.json",
        source:
          "mix meshx.mobile.local_known_good_transport.review --input artifacts/local-ble/<run-id>/transport/evidence.json --json --out tmp/local-known-good-transport-review.json",
        purpose:
          "Review known-good constrained fetch transport metadata before accepting transport wording.",
        required_for: [:known_good_transport_review],
        acceptance_criteria: [
          "Candidate transport decision, standalone interop matrix, tiny read/write probe, known-bad pair separation, constrained-fetch prerequisite, and release-linkage evidence are present.",
          "Blocked known-good transport, GATT fetch success, full-resolution, delivery, trust, routing, and completion claims are called out.",
          "Current known-bad SM-T577U/SM-T390 GATT archive is referenced at artifacts/local-ble/2026-05-13-sm-t577u-sm-t390/hardware/m40-gatt-interop-rerun/.",
          "SM-T577U/SM-T390 GATT status 133 remains recorded as known-bad evidence, not a known-good transport."
        ],
        blocked_claims: [
          :known_good_transport,
          :transport_validated,
          :gatt_fetch_success,
          :full_message_resolution,
          :message_delivery,
          :trusted_delivery,
          :routed_delivery,
          :whole_project_complete
        ]
      },
      %Artifact{
        id: :ux_validation_plan,
        status: :generated,
        path: "tmp/local-inbox-ux-validation-plan.json",
        source:
          "mix meshx.mobile.local_inbox.ux_validation_plan --json --out tmp/local-inbox-ux-validation-plan.json",
        purpose:
          "Archive the Nearby Messages on-device UX validation checklist before target-device evidence review.",
        required_for: [:product_ux_review],
        acceptance_criteria: [
          "Target-device matrix, state coverage, interaction coverage, selected-detail coverage, blocked-claim copy, and visual-density gates remain open.",
          "Production UX, delivery, trust, and routing claims remain blocked.",
          "The plan is archived separately from operator-supplied screenshots or notes."
        ],
        blocked_claims: [
          :production_nearby_messages_ux,
          :delivery,
          :trusted_delivery,
          :routing
        ]
      },
      %Artifact{
        id: :ux_evidence_manifest,
        status: :generated,
        path: "tmp/local-inbox-ux-evidence.json",
        source:
          "mix meshx.mobile.local_inbox.ux_evidence --json --out tmp/local-inbox-ux-evidence.json",
        purpose:
          "Archive Nearby Messages pure surface coverage and open on-device validation gates.",
        required_for: [:product_ux_review],
        acceptance_criteria: [
          "Full, unresolved, gossiped, and stale states remain visible in the fixture surface.",
          "Selected-detail evidence is archived for every fixture state.",
          "Active filter and sort summaries are archived for release review.",
          "Per-row blocked-claim copy is archived for full, unresolved, gossiped, and stale rows.",
          "LocalInboxUxValidationPlan open gates remain visible.",
          "Production UX, delivery, trust, routing, and background claims remain blocked."
        ],
        blocked_claims: [
          :production_nearby_messages_ux,
          :delivery,
          :trusted_delivery,
          :routing,
          :background_operation
        ]
      },
      %Artifact{
        id: :ux_decision_scenario_plan,
        status: :embedded,
        path: "tmp/local-inbox-ux-evidence.json#/ux_decision_scenario_plan",
        source: "LocalInboxUxEvidenceManifest.snapshot().ux_decision_scenario_plan",
        purpose:
          "Archive Nearby Messages UX decision scenarios for keeping pure surface evidence or promoting production UX.",
        required_for: [:product_ux_review],
        acceptance_criteria: [
          "Decision scenarios cover keep_pure_surface_evidence_only and promote_nearby_messages_production_ux.",
          "The production UX scenario lists every LocalInboxUxValidationPlan gate and target-device scenario dimension.",
          "Production UX, delivery, trust, routing, background, and fetch claims remain blocked."
        ],
        blocked_claims: [
          :production_nearby_messages_ux,
          :delivery,
          :trusted_delivery,
          :routing,
          :background_operation
        ]
      },
      %Artifact{
        id: :ux_evidence_template,
        status: :operator_supplied_open,
        path: "artifacts/local-ble/<run-id>/ux/evidence.json",
        source:
          "mix meshx.mobile.local_inbox.ux_review --template --out artifacts/local-ble/<run-id>/ux/evidence.json",
        purpose:
          "Generate incomplete Nearby Messages target-device UX metadata before operator-supplied review.",
        required_for: [:product_ux_review],
        acceptance_criteria: [
          "Template includes target_devices, state_evidence, interaction_evidence, selected_detail_evidence, copy_review, and visual_density_review sections.",
          "Selected detail rows include limitation_copy, next_action_copy, and blocked_claim_copy fields before operator completion.",
          "Template rows list full, unresolved, gossiped, and stale states before operator completion.",
          "State, interaction, selected-detail, copy-review, and visual-density artifacts require evidence_kind to classify every artifact as screenshot or operator_note evidence.",
          "Template remains incomplete until real target-device screenshots or notes and copy/density reviews are supplied."
        ],
        blocked_claims: [
          :production_nearby_messages_ux,
          :delivery,
          :trusted_delivery,
          :routing,
          :background_operation
        ]
      },
      %Artifact{
        id: :ux_evidence_review,
        status: :operator_supplied_open,
        path: "tmp/local-inbox-ux-review.json",
        source:
          "mix meshx.mobile.local_inbox.ux_review --input artifacts/local-ble/<run-id>/ux/evidence.json --json --out tmp/local-inbox-ux-review.json",
        purpose:
          "Review target-device UX attachments before accepting production Nearby Messages UX evidence.",
        required_for: [:product_ux_review],
        acceptance_criteria: [
          "The operator metadata scaffold is completed with real target-device artifacts before review.",
          "Target device metadata names model, OS/API, screen class, and build.",
          "Full, unresolved, gossiped, and stale states are covered by screenshots or notes.",
          "Filter, sort, row selection, and detail panel interaction_evidence with evidence_kind are present.",
          "selected_detail_evidence with evidence_kind, limitation_copy, next_action_copy, blocked_claim_copy, copy_review with evidence_kind, visual_density_review with evidence_kind, control-summary copy, per-state blocked-claim copy, and coverage_summary selected-detail coverage are present."
        ],
        blocked_claims: [
          :delivery,
          :trusted_delivery,
          :routing,
          :background_operation
        ]
      },
      %Artifact{
        id: :lifecycle_validation_plan,
        status: :generated,
        path: "tmp/local-lifecycle-validation-plan.json",
        source:
          "mix meshx.mobile.local_lifecycle.validation_plan --json --out tmp/local-lifecycle-validation-plan.json",
        purpose:
          "Archive the mobile BLE lifecycle hardware validation checklist before operator evidence review.",
        required_for: [:lifecycle_review],
        acceptance_criteria: [
          "current_validated_mode remains foreground_manual.",
          "Target-device, Android foreground-service, Android background BLE, iOS background BLE, restart, scheduled retry, background gossip, and negative claim gates remain blocked.",
          "Background operation, restart, scheduled retry, background gossip, and background delivery claims remain blocked."
        ],
        blocked_claims: [
          :android_foreground_service_ble,
          :android_background_scan,
          :android_background_advertise,
          :ios_background_scan,
          :ios_background_advertise,
          :automatic_ble_restart,
          :scheduled_retry,
          :background_gossip,
          :background_delivery
        ]
      },
      %Artifact{
        id: :lifecycle_evidence_manifest,
        status: :generated,
        path: "tmp/local-lifecycle-evidence.json",
        source:
          "mix meshx.mobile.local_lifecycle.evidence --json --out tmp/local-lifecycle-evidence.json",
        purpose:
          "Archive foreground/manual lifecycle evidence and blocked background lifecycle gates.",
        required_for: [:lifecycle_review],
        acceptance_criteria: [
          "current_mode remains foreground_manual.",
          "Android foreground-service, Android/iOS background BLE, restart, scheduled retry, and background gossip claims remain blocked.",
          "LocalLifecycleHardwareValidationPlan open gates remain visible."
        ],
        blocked_claims: [
          :android_foreground_service_ble,
          :android_background_scan,
          :android_background_advertise,
          :ios_background_scan,
          :ios_background_advertise,
          :automatic_ble_restart,
          :scheduled_retry,
          :background_gossip,
          :background_delivery
        ]
      },
      %Artifact{
        id: :lifecycle_decision_scenario_plan,
        status: :embedded,
        path: "tmp/local-lifecycle-evidence.json#/lifecycle_decision_scenario_plan",
        source: "LocalLifecycleEvidenceManifest.snapshot().lifecycle_decision_scenario_plan",
        purpose:
          "Archive lifecycle decision scenarios for keeping foreground/manual mode or enabling background lifecycle behavior.",
        required_for: [:lifecycle_review],
        acceptance_criteria: [
          "Decision scenarios cover keep_foreground_manual and enable_background_lifecycle.",
          "The background lifecycle scenario lists every LocalLifecycleHardwareValidationPlan gate.",
          "Android foreground-service, Android/iOS background BLE, restart, scheduled retry, background gossip, and background delivery claims remain blocked."
        ],
        blocked_claims: [
          :android_foreground_service_ble,
          :android_background_scan,
          :android_background_advertise,
          :ios_background_scan,
          :ios_background_advertise,
          :automatic_ble_restart,
          :scheduled_retry,
          :background_gossip,
          :background_delivery
        ]
      },
      %Artifact{
        id: :lifecycle_hardware_evidence_template,
        status: :operator_supplied_open,
        path: "artifacts/local-ble/<run-id>/lifecycle/evidence.json",
        source:
          "mix meshx.mobile.local_lifecycle.hardware_review --template --out artifacts/local-ble/<run-id>/lifecycle/evidence.json",
        purpose:
          "Generate incomplete lifecycle hardware evidence metadata before operator-supplied lifecycle review.",
        required_for: [:lifecycle_review],
        acceptance_criteria: [
          "Template lists every mobile lifecycle hardware validation gate.",
          "Generated metadata remains incomplete until artifact paths, summaries, commands, and blocked-claim callouts are supplied.",
          "Template review keeps foreground-service, background BLE, restart, retry, gossip, and delivery claims blocked."
        ],
        blocked_claims: [
          :android_foreground_service_ble,
          :android_background_scan,
          :android_background_advertise,
          :ios_background_scan,
          :ios_background_advertise,
          :automatic_ble_restart,
          :scheduled_retry,
          :background_gossip,
          :background_delivery
        ]
      },
      %Artifact{
        id: :lifecycle_hardware_evidence_review,
        status: :operator_supplied_open,
        path: "tmp/local-lifecycle-hardware-review.json",
        source:
          "mix meshx.mobile.local_lifecycle.hardware_review --input artifacts/local-ble/<run-id>/lifecycle/evidence.json --json --out tmp/local-lifecycle-hardware-review.json",
        purpose:
          "Review mobile lifecycle hardware evidence before accepting foreground-service, background BLE, restart, retry, or background gossip release wording.",
        required_for: [:lifecycle_review],
        acceptance_criteria: [
          "Target device, Android foreground service, Android/iOS background BLE, restart, retry, background gossip, and negative evidence are present.",
          "Blocked foreground-service, background BLE, restart, retry, gossip, and background delivery claims are called out.",
          "Foreground/manual remains the only validated lifecycle mode until implementation-backed device evidence is validated."
        ],
        blocked_claims: [
          :android_foreground_service_ble,
          :android_background_scan,
          :android_background_advertise,
          :ios_background_scan,
          :ios_background_advertise,
          :automatic_ble_restart,
          :scheduled_retry,
          :background_gossip,
          :background_delivery
        ]
      },
      %Artifact{
        id: :multi_hop_hardware_evidence_manifest,
        status: :generated,
        path: "tmp/local-multi-hop-hardware-evidence.json",
        source:
          "mix meshx.mobile.local_multi_hop_hardware.evidence --json --out tmp/local-multi-hop-hardware-evidence.json",
        purpose:
          "Archive replay evidence, current one-hop hardware scope, and blocked physical multi-hop gates.",
        required_for: [:multi_hop_hardware_review],
        acceptance_criteria: [
          "Replay fixture evidence remains separate from physical hardware proof.",
          "Current hardware scope remains one-hop legacy beacon gossip.",
          "Origin, relay, observer, replay-normalization, TTL/suppression, and release artifact gates remain visible."
        ],
        blocked_claims: [
          :multi_hop_hardware_gossip,
          :multi_hop_hardware_delivery,
          :routed_delivery,
          :guaranteed_delivery,
          :trusted_delivery,
          :background_operation
        ]
      },
      %Artifact{
        id: :multi_hop_hardware_evidence_template,
        status: :operator_supplied_open,
        path: "artifacts/local-ble/<run-id>/multi-hop/evidence.json",
        source:
          "mix meshx.mobile.local_multi_hop_hardware.review --template --out artifacts/local-ble/<run-id>/multi-hop/evidence.json",
        purpose:
          "Generate incomplete physical multi-hop hardware metadata before operator-supplied review.",
        required_for: [:multi_hop_hardware_review],
        acceptance_criteria: [
          "Template lists every physical multi-hop hardware validation gate.",
          "Generated metadata remains incomplete until artifact paths, summaries, commands, and blocked-claim callouts are supplied.",
          "Template review keeps multi-hop gossip, routed delivery, guaranteed delivery, trusted delivery, background operation, and completion claims blocked."
        ],
        blocked_claims: [
          :multi_hop_hardware_gossip,
          :multi_hop_hardware_delivery,
          :routed_delivery,
          :guaranteed_delivery,
          :trusted_delivery,
          :background_operation,
          :whole_project_complete
        ]
      },
      %Artifact{
        id: :multi_hop_hardware_evidence_review,
        status: :operator_supplied_open,
        path: "tmp/local-multi-hop-hardware-review.json",
        source:
          "mix meshx.mobile.local_multi_hop_hardware.review --input artifacts/local-ble/<run-id>/multi-hop/evidence.json --json --out tmp/local-multi-hop-hardware-review.json",
        purpose:
          "Review physical multi-hop origin/relay/observer metadata before accepting multi-hop wording.",
        required_for: [:multi_hop_hardware_review],
        acceptance_criteria: [
          "Three-role device matrix, origin/relay/observer capture, replay fixture, TTL/suppression, one-hop negative, and release-linkage evidence are present.",
          "Blocked multi-hop gossip, hardware delivery, routed delivery, guaranteed delivery, trusted delivery, background, and completion claims are called out.",
          "Replay fixture evidence and current one-hop hardware proof remain separate from physical multi-hop proof."
        ],
        blocked_claims: [
          :multi_hop_hardware_gossip,
          :multi_hop_hardware_delivery,
          :routed_delivery,
          :guaranteed_delivery,
          :trusted_delivery,
          :background_operation,
          :whole_project_complete
        ]
      },
      %Artifact{
        id: :ios_parity_evidence_manifest,
        status: :generated,
        path: "tmp/local-ios-parity-evidence.json",
        source:
          "mix meshx.mobile.local_ios_parity.evidence --json --out tmp/local-ios-parity-evidence.json",
        purpose: "Archive iOS contract-only state and blocked advert-only parity gates.",
        required_for: [:ios_parity_review],
        acceptance_criteria: [
          "current_ios_mode remains contract_only.",
          "iOS hardware participation, legacy beacon observe/gossip, full-envelope advert, replay fixture, and background BLE claims remain blocked.",
          "LocalIOSParityHardwareValidationPlan open gates remain visible."
        ],
        blocked_claims: [
          :ios_hardware_participation,
          :ios_advert_only_validation,
          :ios_legacy_beacon_observed,
          :ios_legacy_beacon_gossip,
          :ios_full_envelope_advert,
          :ios_hardware_replay_fixture,
          :ios_background_ble,
          :ios_parity_claim
        ]
      },
      %Artifact{
        id: :ios_parity_decision_scenario_plan,
        status: :embedded,
        path: "tmp/local-ios-parity-evidence.json#/ios_parity_decision_scenario_plan",
        source: "LocalIOSParityEvidenceManifest.snapshot().ios_parity_decision_scenario_plan",
        purpose:
          "Archive iOS parity decision scenarios for keeping contract-only mode or enabling iOS advert-only participation.",
        required_for: [:ios_parity_review],
        acceptance_criteria: [
          "Decision scenarios cover keep_ios_contract_only and enable_ios_advert_only_participation.",
          "The iOS advert-only participation scenario lists every LocalIOSParityHardwareValidationPlan gate.",
          "iOS hardware participation, legacy beacon observe/gossip, full-envelope advert, replay fixture, background BLE, and parity claims remain blocked."
        ],
        blocked_claims: [
          :ios_hardware_participation,
          :ios_advert_only_validation,
          :ios_legacy_beacon_observed,
          :ios_legacy_beacon_gossip,
          :ios_full_envelope_advert,
          :ios_hardware_replay_fixture,
          :ios_background_ble,
          :ios_parity_claim
        ]
      },
      %Artifact{
        id: :ios_parity_hardware_evidence_template,
        status: :operator_supplied_open,
        path: "artifacts/local-ble/<run-id>/ios/evidence.json",
        source:
          "mix meshx.mobile.local_ios_parity.hardware_review --template --out artifacts/local-ble/<run-id>/ios/evidence.json",
        purpose:
          "Generate incomplete iOS advert-only hardware evidence metadata before operator-supplied parity review.",
        required_for: [:ios_parity_review],
        acceptance_criteria: [
          "Template lists every iOS advert-only hardware validation gate.",
          "Generated metadata remains incomplete until artifact paths, summaries, commands, and blocked-claim callouts are supplied.",
          "Template review keeps iOS participation, beacon observe/gossip, full-envelope advert, background BLE, and parity claims blocked."
        ],
        blocked_claims: [
          :ios_hardware_participation,
          :ios_advert_only_validation,
          :ios_legacy_beacon_observed,
          :ios_legacy_beacon_gossip,
          :ios_full_envelope_advert,
          :ios_full_message_observation,
          :ios_hardware_replay_fixture,
          :ios_background_ble,
          :ios_background_scan,
          :ios_background_advertise,
          :ios_parity_claim
        ]
      },
      %Artifact{
        id: :ios_parity_operator_capture_plan,
        status: :embedded,
        path: "tmp/local-ios-parity-evidence.json#/operator_capture_plan",
        source: "LocalIOSParityEvidenceManifest.snapshot().operator_capture_plan",
        purpose:
          "Archive iOS parity capture slots for target devices, canonical ingress, legacy beacon observe/gossip, full-envelope capability, replay fixture, background boundary, and negative evidence.",
        required_for: [:ios_parity_review],
        acceptance_criteria: [
          "Capture sections cover every LocalIOSParityHardwareEvidenceReview gate.",
          "Every section lists artifact path, summary, test command, evidence type, and blocked claim callout requirements.",
          "iOS observe, gossip, full-envelope advert, background BLE, hardware participation, and parity claims remain blocked."
        ],
        blocked_claims: [
          :ios_hardware_participation,
          :ios_advert_only_validation,
          :ios_legacy_beacon_observed,
          :ios_legacy_beacon_gossip,
          :ios_full_envelope_advert,
          :ios_full_message_observation,
          :ios_hardware_replay_fixture,
          :ios_background_ble,
          :ios_background_scan,
          :ios_background_advertise,
          :ios_parity_claim
        ]
      },
      %Artifact{
        id: :ios_parity_hardware_evidence_review,
        status: :operator_supplied_open,
        path: "tmp/local-ios-parity-hardware-review.json",
        source:
          "mix meshx.mobile.local_ios_parity.hardware_review --input artifacts/local-ble/<run-id>/ios/evidence.json --json --out tmp/local-ios-parity-hardware-review.json",
        purpose:
          "Review iOS advert-only hardware metadata before accepting iOS participation wording.",
        required_for: [:ios_parity_review],
        acceptance_criteria: [
          "iOS target device, canonical ingress, beacon observe/gossip, full-envelope capability, hardware replay, background-boundary, and negative evidence metadata are present.",
          "Blocked iOS participation, beacon observe/gossip, full-envelope advert, replay fixture, background BLE, and parity claims are called out.",
          "iOS remains contract-only until native implementation and hardware evidence are separately validated."
        ],
        blocked_claims: [
          :ios_hardware_participation,
          :ios_advert_only_validation,
          :ios_legacy_beacon_observed,
          :ios_legacy_beacon_gossip,
          :ios_full_envelope_advert,
          :ios_full_message_observation,
          :ios_hardware_replay_fixture,
          :ios_background_ble,
          :ios_background_scan,
          :ios_background_advertise,
          :ios_parity_claim
        ]
      },
      %Artifact{
        id: :production_persistence_lifecycle_plan,
        status: :generated,
        path: "tmp/local-persistence-lifecycle-plan.json",
        source:
          "mix meshx.mobile.local_persistence.lifecycle_plan --json --out tmp/local-persistence-lifecycle-plan.json",
        purpose:
          "Archive the production-default persistence lifecycle checklist before operator evidence review.",
        required_for: [:persistence_review],
        acceptance_criteria: [
          "current_default_mode remains memory_only.",
          "Default decision, schema migration, scheduled cleanup, background-safe writer, on-device restore, and release artifact gates remain blocked.",
          "Default persistence, background persistence, delivery-record, full-resolution, and trusted-message claims remain blocked."
        ],
        blocked_claims: [
          :default_app_persistence,
          :background_persistence,
          :delivery_record,
          :full_message_resolution,
          :trusted_message_delivery
        ]
      },
      %Artifact{
        id: :persistence_evidence_manifest,
        status: :generated,
        path: "tmp/local-persistence-evidence.json",
        source:
          "mix meshx.mobile.local_persistence.evidence --json --out tmp/local-persistence-evidence.json",
        purpose:
          "Archive opt-in durable local inbox evidence and blocked production-default lifecycle gates.",
        required_for: [:persistence_review],
        acceptance_criteria: [
          "current_default_mode remains memory_only unless product gates close.",
          "opt-in durable snapshots are described as read models, not delivery records.",
          "Production default, background persistence, delivery-record, and full-resolution claims remain blocked."
        ],
        blocked_claims: [
          :default_app_persistence,
          :background_persistence,
          :delivery_record,
          :full_message_resolution,
          :trusted_message_delivery
        ]
      },
      %Artifact{
        id: :production_persistence_evidence_review,
        status: :operator_supplied_open,
        path: "tmp/local-persistence-production-review.json",
        source:
          "mix meshx.mobile.local_persistence.production_review --template --out artifacts/local-ble/<run-id>/persistence/evidence.json && mix meshx.mobile.local_persistence.production_review --input artifacts/local-ble/<run-id>/persistence/evidence.json --json --out tmp/local-persistence-production-review.json",
        purpose:
          "Review production-default persistence lifecycle evidence before accepting default-persistence release wording.",
        required_for: [:persistence_review],
        acceptance_criteria: [
          "The operator metadata scaffold is generated with --template, then completed with real persistence lifecycle artifacts before review.",
          "Product decision, schema migration, scheduled cleanup, writer, restore, and release artifact evidence are present.",
          "Blocked delivery-record, trusted-message, background-persistence, and full-resolution claims are called out.",
          "Default app persistence remains disabled until implementation and on-device evidence are separately validated."
        ],
        blocked_claims: [
          :default_app_persistence,
          :background_persistence,
          :delivery_record,
          :full_message_resolution,
          :trusted_message_delivery
        ]
      },
      %Artifact{
        id: :routing_validation_plan,
        status: :generated,
        path: "tmp/local-routing-validation-plan.json",
        source:
          "mix meshx.mobile.local_routing.validation_plan --json --out tmp/local-routing-validation-plan.json",
        purpose:
          "Archive the production routing hardware validation checklist before operator evidence review.",
        required_for: [:routing_review],
        acceptance_criteria: [
          "current_mode remains advert_only_non_routing.",
          "Route table, deterministic selection, forwarding, delivery semantics, multi-hop hardware, TTL/loop, release, and negative claim gates remain blocked.",
          "Route selection, forwarding, routed delivery, ACK/retry, guaranteed delivery, and multi-hop hardware routing claims remain blocked."
        ],
        blocked_claims: [
          :route_table_available,
          :route_selection_available,
          :live_forwarding_service,
          :routed_delivery,
          :guaranteed_delivery,
          :ack_backed_delivery,
          :retry_backed_delivery,
          :multi_hop_hardware_routing
        ]
      },
      %Artifact{
        id: :routing_evidence_manifest,
        status: :generated,
        path: "tmp/local-routing-evidence.json",
        source:
          "mix meshx.mobile.local_routing.evidence --json --out tmp/local-routing-evidence.json",
        purpose: "Archive current route-candidate evidence and blocked production routing gates.",
        required_for: [:routing_review],
        acceptance_criteria: [
          "Route candidates remain read-model entries, not forwarding actions.",
          "Production route selection, forwarding, routed delivery, ACK/retry, and multi-hop hardware claims remain blocked.",
          "LocalRoutingHardwareValidationPlan open gates remain visible."
        ],
        blocked_claims: [
          :route_selection_available,
          :live_forwarding_service,
          :routed_delivery,
          :guaranteed_delivery,
          :ack_backed_delivery,
          :retry_backed_delivery,
          :multi_hop_hardware_routing
        ]
      },
      %Artifact{
        id: :routing_decision_scenario_plan,
        status: :embedded,
        path: "tmp/local-routing-evidence.json#/routing_decision_scenario_plan",
        source: "LocalRoutingEvidenceManifest.snapshot().routing_decision_scenario_plan",
        purpose:
          "Archive routing decision scenarios for keeping advert-only non-routing mode or enabling production routing.",
        required_for: [:routing_review],
        acceptance_criteria: [
          "Decision scenarios cover keep_advert_only_non_routing and enable_production_routing.",
          "The production routing scenario lists every LocalRoutingHardwareValidationPlan gate.",
          "Route selection, forwarding, routed delivery, ACK/retry, guaranteed delivery, and multi-hop hardware routing claims remain blocked."
        ],
        blocked_claims: [
          :route_selection_available,
          :live_forwarding_service,
          :routed_delivery,
          :guaranteed_delivery,
          :ack_backed_delivery,
          :retry_backed_delivery,
          :multi_hop_hardware_routing
        ]
      },
      %Artifact{
        id: :production_routing_evidence_template,
        status: :operator_supplied_open,
        path: "artifacts/local-ble/<run-id>/routing/evidence.json",
        source:
          "mix meshx.mobile.local_routing.production_review --template --out artifacts/local-ble/<run-id>/routing/evidence.json",
        purpose:
          "Generate incomplete routing evidence metadata before operator-supplied routing review.",
        required_for: [:routing_review],
        acceptance_criteria: [
          "Template lists every production routing validation gate.",
          "Generated metadata remains incomplete until artifact paths, summaries, commands, and blocked-claim callouts are supplied.",
          "Template review keeps route table, forwarding, routed delivery, ACK/retry, and multi-hop claims blocked."
        ],
        blocked_claims: [
          :route_table_available,
          :route_selection_available,
          :live_forwarding_service,
          :routed_delivery,
          :guaranteed_delivery,
          :ack_backed_delivery,
          :retry_backed_delivery,
          :multi_hop_hardware_routing
        ]
      },
      %Artifact{
        id: :production_routing_evidence_review,
        status: :operator_supplied_open,
        path: "tmp/local-routing-production-review.json",
        source:
          "mix meshx.mobile.local_routing.production_review --input artifacts/local-ble/<run-id>/routing/evidence.json --json --out tmp/local-routing-production-review.json",
        purpose:
          "Review production routing evidence before accepting routing, forwarding, delivery, or multi-hop release wording.",
        required_for: [:routing_review],
        acceptance_criteria: [
          "Route table, route selection, forwarding, delivery semantics, multi-hop rig, TTL/loop, release, and negative evidence are present.",
          "Blocked route table, selection, forwarding, routed delivery, ACK/retry, and multi-hop claims are called out.",
          "Routing remains disabled until implementation-backed and hardware evidence are separately validated."
        ],
        blocked_claims: [
          :route_table_available,
          :route_selection_available,
          :live_forwarding_service,
          :routed_delivery,
          :guaranteed_delivery,
          :ack_backed_delivery,
          :retry_backed_delivery,
          :multi_hop_hardware_routing
        ]
      },
      %Artifact{
        id: :hardware_evidence_manifest,
        status: :embedded,
        path: "tmp/local-release.json#/hardware_evidence",
        source: "LocalReleaseManifest.snapshot().hardware_evidence",
        purpose: "Archive hardware gates and open evidence requirements.",
        required_for: [:hardware_evidence_review],
        acceptance_criteria: [
          "Passed gates support only their listed required_for claims.",
          "Open gates remain visible in the bundle."
        ],
        blocked_claims: [
          :full_message_resolution,
          :multi_hop_hardware_delivery,
          :ios_parity
        ]
      },
      %Artifact{
        id: :recent_evidence_inventory,
        status: :generated,
        path: "tmp/local-release-recent-evidence.json",
        source:
          "mix meshx.mobile.local_release.recent_evidence --json --out tmp/local-release-recent-evidence.json",
        purpose:
          "Archive recent no-new-hardware evidence slices before release-candidate wording review.",
        required_for: [:release_planning, :operator_release_review],
        acceptance_criteria: [
          "Every recent evidence slice names the objective-specific review still required.",
          "Recent evidence supports only advert-only release traceability, not completion.",
          "Completion, delivery, trust, routing, background, iOS parity, and full-resolution claims remain blocked."
        ],
        blocked_claims: [
          :whole_project_complete,
          :message_delivery,
          :trusted_delivery,
          :routed_delivery,
          :background_operation,
          :ios_parity,
          :full_message_resolution
        ]
      },
      %Artifact{
        id: :security_validation_plan,
        status: :generated,
        path: "tmp/local-security-validation-plan.json",
        source:
          "mix meshx.mobile.local_security.validation_plan --json --out tmp/local-security-validation-plan.json",
        purpose:
          "Archive the authenticated local BLE security validation checklist before release evidence review.",
        required_for: [:security_evidence_review],
        acceptance_criteria: [
          "current_mode remains unsigned_local_ble_observations.",
          "Peer enrollment, authorship, replay lifecycle, trust lifecycle, canonical replay, beacon authentication, release evidence, and negative claim review gates remain blocked.",
          "Authenticated peer, authenticated message, trusted-message, trusted-delivery, and fresh-message claims remain blocked."
        ],
        blocked_claims: [
          :authenticated_peer_identity,
          :authenticated_message,
          :trusted_message,
          :trusted_delivery,
          :fresh_message
        ]
      },
      %Artifact{
        id: :security_evidence_manifest,
        status: :generated,
        path: "tmp/local-security-evidence.json",
        source:
          "mix meshx.mobile.local_security.evidence --json --out tmp/local-security-evidence.json",
        purpose:
          "Archive current local security evidence, open validation gates, blocked claims, and release review state.",
        required_for: [:security_evidence_review],
        acceptance_criteria: [
          "security_evidence_complete? is false while operator review or underlying gates remain open.",
          "authenticated, trusted-message, and trusted-delivery claims remain blocked.",
          "LocalSecurityReleaseEvidenceReview status remains visible."
        ],
        blocked_claims: [
          :authenticated_peer_identity,
          :authenticated_message,
          :trusted_message,
          :trusted_delivery
        ]
      },
      %Artifact{
        id: :security_decision_scenario_plan,
        status: :embedded,
        path: "tmp/local-security-evidence.json#/security_decision_scenario_plan",
        source: "LocalSecurityEvidenceManifest.snapshot().security_decision_scenario_plan",
        purpose:
          "Archive security decision scenarios for keeping unsigned local observations or enabling authenticated local trust.",
        required_for: [:security_evidence_review],
        acceptance_criteria: [
          "Decision scenarios cover keep_unsigned_local_observation and enable_authenticated_local_trust.",
          "The authenticated local trust scenario lists every LocalSecurityIdentityValidationPlan gate.",
          "Authenticated identity, authenticated message, trusted-message, trusted-delivery, and freshness claims remain blocked."
        ],
        blocked_claims: [
          :authenticated_peer_identity,
          :authenticated_message,
          :trusted_message,
          :trusted_delivery,
          :fresh_message
        ]
      },
      %Artifact{
        id: :security_operator_capture_plan,
        status: :embedded,
        path: "tmp/local-security-evidence.json#/operator_capture_plan",
        source: "LocalSecurityEvidenceManifest.snapshot().operator_capture_plan",
        purpose:
          "Archive security capture slots for peer/key enrollment, authorship, replay lifecycle, trust lifecycle, canonical replay, beacon authentication, release evidence, and negative claim review.",
        required_for: [:security_evidence_review],
        acceptance_criteria: [
          "Capture sections cover every LocalSecurityReleaseEvidenceReview plan gate.",
          "Every section lists attachment fields, evidence type, blocked claims, and operator review requirement.",
          "Authenticated identity, authenticated message, trusted-message, trusted-delivery, and freshness claims remain blocked."
        ],
        blocked_claims: [
          :authenticated_peer_identity,
          :authenticated_message,
          :trusted_message,
          :trusted_delivery,
          :fresh_message
        ]
      },
      %Artifact{
        id: :security_release_evidence_review,
        status: :operator_supplied_open,
        path: "tmp/local-security-release-review.json",
        source:
          "mix meshx.mobile.local_security.release_review --template --out artifacts/local-ble/<run-id>/security/evidence.json && mix meshx.mobile.local_security.release_review --input artifacts/local-ble/<run-id>/security/evidence.json --json --out tmp/local-security-release-review.json",
        purpose:
          "Review security evidence package metadata before accepting authenticated or trusted wording.",
        required_for: [:security_evidence_review],
        acceptance_criteria: [
          "The operator metadata scaffold is generated with --template, then completed with real security artifacts before review.",
          "Readiness, release, and security manifest paths are present.",
          "Security attachments cover every LocalSecurityIdentityValidationPlan gate.",
          "Blocked authenticated, trusted-message, trusted-delivery, and fresh-message claims are called out and operator-reviewed."
        ],
        blocked_claims: [
          :authenticated_peer_identity,
          :authenticated_message,
          :trusted_message,
          :trusted_delivery,
          :fresh_message
        ]
      },
      %Artifact{
        id: :advert_gossip_audit_output,
        status: :generated,
        path: "tmp/advert-gossip-audit.txt",
        source:
          "mix meshx.mobile.advert_gossip.audit apps/meshx_mobile_app/test/fixtures/advert_gossip_scenarios",
        purpose: "Archive deterministic replay evidence for advert gossip policy.",
        required_for: [:advert_gossip_replay_evidence],
        acceptance_criteria: [
          "All fixture scenarios print PASS.",
          "Replay evidence is not described as physical multi-hop hardware proof."
        ],
        blocked_claims: [:multi_hop_hardware_delivery]
      },
      %Artifact{
        id: :hardware_log_bundle,
        status: :operator_supplied_open,
        path: "artifacts/local-ble/<run-id>/hardware/",
        source: "Operator-attached adb/logcat summaries and validation ledgers.",
        purpose: "Attach concrete device evidence for any hardware claim in release notes.",
        required_for: [:hardware_claims],
        acceptance_criteria: [
          "Each attached log records device model, OS/API version, role, command, and summary path.",
          "Each attachment declares the gate-specific evidence type for every cited hardware gate.",
          "Current known-bad GATT blocker logs are attached or linked from artifacts/local-ble/2026-05-13-sm-t577u-sm-t390/hardware/m40-gatt-interop-rerun/.",
          "Open hardware gates are called out explicitly when logs are missing.",
          "LocalReleaseCandidateEvidenceReview accepts the attachment metadata."
        ],
        blocked_claims: [
          :full_message_resolution,
          :known_good_gatt_fetch,
          :multi_hop_hardware_delivery,
          :ios_parity
        ]
      },
      %Artifact{
        id: :release_candidate_evidence_template,
        status: :operator_supplied_open,
        path: "artifacts/local-ble/<run-id>/release-candidate/evidence.json",
        source:
          "mix meshx.mobile.local_release.candidate_review --template --out artifacts/local-ble/<run-id>/release-candidate/evidence.json",
        purpose:
          "Generate incomplete release-candidate evidence metadata before operator-supplied review.",
        required_for: [:operator_release_review],
        acceptance_criteria: [
          "Template exposes manifest paths, UX review path, UX review summary, hardware attachment metadata, and operator wording fields.",
          "Generated metadata remains incomplete until real paths, ready UX review output with coverage summary, device evidence, and blocked-claim/open-gate callouts are supplied.",
          "Template review keeps whole-project completion, delivery, trust, routing, multi-hop, full-resolution, background, and iOS parity claims blocked."
        ],
        blocked_claims: [
          :whole_project_complete,
          :guaranteed_delivery,
          :trusted_delivery,
          :authenticated_message_delivery,
          :routed_delivery,
          :multi_hop_hardware_delivery,
          :full_message_resolution_from_beacon_refs,
          :background_mobile_operation,
          :ios_advert_only_participation
        ]
      },
      %Artifact{
        id: :release_operator_capture_plan,
        status: :embedded,
        path: "tmp/local-release.json#/operator_capture_plan",
        source: "LocalReleaseManifest.snapshot().operator_capture_plan",
        purpose:
          "Archive release-candidate capture slots for manifests, objective reviews, hardware attachments, operator notes, and final review.",
        required_for: [:operator_release_review],
        acceptance_criteria: [
          "Capture sections list required release manifest, objective review, hardware attachment, operator note, and final candidate review inputs.",
          "Allowed wording remains limited to messages seen nearby from passive BLE advertisement observations.",
          "Blocked whole-project completion, delivery, trust, routing, background, full-resolution, multi-hop hardware, and iOS parity claims remain called out."
        ],
        blocked_claims: [
          :whole_project_complete,
          :guaranteed_delivery,
          :trusted_delivery,
          :authenticated_message_delivery,
          :routed_delivery,
          :multi_hop_hardware_delivery,
          :full_message_resolution_from_beacon_refs,
          :background_mobile_operation,
          :ios_advert_only_participation
        ]
      },
      %Artifact{
        id: :operator_release_notes,
        status: :open,
        path: "docs/local_ble_release_artifact_bundle.md",
        source:
          "Operator-authored release note reviewed against LocalReleaseManifest.release_wording.",
        purpose: "Document allowed and blocked wording for the release candidate.",
        required_for: [:operator_release_review],
        acceptance_criteria: [
          "Uses 'messages seen nearby' wording.",
          "Does not claim delivery, trust, routing, background behavior, or iOS parity.",
          "References readiness, JSON completion audit, plain-text completion audit, blocker matrix, release manifest, and ready UX review paths.",
          "LocalReleaseCandidateEvidenceReview accepts JSON completion audit, plain-text completion audit, blocker matrix, ready UX review summary, blocked-claim, and open-gate callouts."
        ],
        blocked_claims: [
          :guaranteed_delivery,
          :trusted_delivery,
          :routed_delivery,
          :background_operation,
          :ios_parity
        ]
      }
    ]
  end

  @spec open_artifacts() :: [Artifact.t()]
  def open_artifacts do
    Enum.filter(artifacts(), &(&1.status in [:operator_supplied_open, :open]))
  end

  @spec required_commands() :: [binary()]
  def required_commands do
    artifacts()
    |> Enum.map(& &1.source)
    |> Enum.filter(&String.starts_with?(&1, "mix "))
  end

  @spec snapshot() :: map()
  def snapshot do
    artifacts = artifacts()
    open_artifacts = open_artifacts()

    %{
      bundle_version: 1,
      boundary: :advert_only_local_release_candidate_bundle,
      release_candidate_complete?: false,
      release_scope: release_scope(),
      artifacts: artifacts,
      open_artifacts: open_artifacts,
      artifact_count: length(artifacts),
      open_artifact_count: length(open_artifacts),
      required_commands: required_commands(),
      notes: [
        "Generated and embedded artifacts define the release boundary; they are not hardware proof by themselves.",
        "Operator-supplied hardware logs are required before any hardware claim beyond the passed one-hop beacon gate.",
        "Release notes must preserve LocalReleaseManifest.release_wording blocked claims."
      ]
    }
  end

  defp release_scope do
    %{
      current_validated_mode: :advertisement_only_local_mesh,
      allowed_release_wording: [
        "messages seen nearby",
        "passive BLE advertisement observations",
        "legacy beacon refs are unresolved pointers",
        "full-envelope adverts only where capability-proven"
      ],
      blocked_release_wording: [
        :whole_project_complete,
        :message_delivery,
        :trusted_delivery,
        :authenticated_message_delivery,
        :routed_delivery,
        :full_message_resolution_from_beacon_refs,
        :known_good_fetch_transport,
        :multi_hop_hardware_delivery,
        :background_mobile_operation,
        :ios_advert_only_participation
      ],
      required_before_release_candidate_complete: [
        :fresh_release_manifest,
        :completion_audit,
        :blocker_matrix,
        :ready_target_device_ux_review,
        :hardware_attachment_review,
        :operator_release_note_review
      ],
      notes: [
        "Advert-only local release wording is narrower than whole-project completion.",
        "A release candidate may describe nearby observations only after operator evidence is attached and reviewed.",
        "Open hardware, transport, iOS, routing, security, lifecycle, and persistence gates must remain visible."
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
