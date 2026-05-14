defmodule MeshxMobileApp.BLE.LocalReleaseArtifactBundleTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.{LocalReleaseArtifactBundle, LocalReleaseManifest}

  test "snapshot lists generated, embedded, and operator-supplied release artifacts" do
    snapshot = LocalReleaseArtifactBundle.snapshot()

    assert snapshot.bundle_version == 1
    assert snapshot.boundary == :advert_only_local_release_candidate_bundle
    refute snapshot.release_candidate_complete?
    assert snapshot.release_scope.current_validated_mode == :advertisement_only_local_mesh
    assert "messages seen nearby" in snapshot.release_scope.allowed_release_wording
    assert :whole_project_complete in snapshot.release_scope.blocked_release_wording

    assert :ready_target_device_ux_review in snapshot.release_scope.required_before_release_candidate_complete

    assert snapshot.artifact_count == 49
    assert snapshot.open_artifact_count == 19
    assert length(snapshot.required_commands) == 37

    ids = Enum.map(snapshot.artifacts, & &1.id)

    assert :readiness_manifest in ids
    assert :release_manifest in ids
    assert :completion_audit_manifest in ids
    assert :completion_audit_standalone in ids
    assert :completion_audit_plain_text_review in ids
    assert :completion_blocker_matrix in ids
    assert :full_message_resolution_evidence_manifest in ids
    assert :full_resolution_transport_evidence_review in ids
    assert :known_good_transport_evidence_review in ids
    assert :ux_evidence_manifest in ids
    assert :ux_decision_scenario_plan in ids
    assert :ux_evidence_template in ids
    assert :ux_evidence_review in ids
    assert :ios_parity_evidence_manifest in ids
    assert :ios_parity_decision_scenario_plan in ids
    assert :ios_parity_operator_capture_plan in ids
    assert :ios_parity_hardware_evidence_review in ids
    assert :lifecycle_validation_plan in ids
    assert :lifecycle_evidence_manifest in ids
    assert :lifecycle_decision_scenario_plan in ids
    assert :lifecycle_hardware_evidence_review in ids
    assert :multi_hop_hardware_evidence_manifest in ids
    assert :multi_hop_hardware_evidence_review in ids
    assert :production_persistence_lifecycle_plan in ids
    assert :persistence_evidence_manifest in ids
    assert :production_persistence_evidence_review in ids
    assert :routing_validation_plan in ids
    assert :routing_evidence_manifest in ids
    assert :routing_decision_scenario_plan in ids
    assert :production_routing_evidence_review in ids
    assert :hardware_evidence_manifest in ids
    assert :recent_evidence_inventory in ids
    assert :security_validation_plan in ids
    assert :security_evidence_manifest in ids
    assert :security_decision_scenario_plan in ids
    assert :security_operator_capture_plan in ids
    assert :security_release_evidence_review in ids
    assert :advert_gossip_audit_output in ids
    assert :hardware_log_bundle in ids
    assert :release_operator_capture_plan in ids
    assert :operator_release_notes in ids
  end

  test "snapshot exposes release artifact source commands as required command gates" do
    snapshot = LocalReleaseArtifactBundle.snapshot()

    required_command_fragments = [
      "local_readiness.audit",
      "local_completion.audit",
      "local-completion-audit.txt",
      "local_release.manifest",
      "local_completion.blocker_matrix",
      "local_full_resolution.evidence",
      "local_full_resolution.transport_review --template",
      "local_full_resolution.transport_review",
      "local_known_good_transport.review --template",
      "local_known_good_transport.review",
      "local_inbox.ux_evidence",
      "local_inbox.ux_review --template",
      "local_inbox.ux_review",
      "local_lifecycle.validation_plan",
      "local_lifecycle.evidence",
      "local_lifecycle.hardware_review --template",
      "local_lifecycle.hardware_review",
      "local_multi_hop_hardware.evidence",
      "local_multi_hop_hardware.review --template",
      "local_multi_hop_hardware.review",
      "local_ios_parity.evidence",
      "local_ios_parity.hardware_review --template",
      "local_ios_parity.hardware_review",
      "local_persistence.evidence",
      "local_persistence.production_review",
      "local_routing.production_review --template",
      "local_routing.evidence",
      "local_routing.production_review",
      "local_release.recent_evidence",
      "local_security.evidence",
      "local_security.release_review",
      "local_release.candidate_review --template",
      "advert_gossip.audit"
    ]

    for fragment <- required_command_fragments do
      assert Enum.any?(snapshot.required_commands, &String.contains?(&1, fragment))
    end
  end

  test "JSON snapshot preserves advert-only release wording scope" do
    snapshot = LocalReleaseArtifactBundle.json_snapshot()

    assert snapshot["release_scope"]["current_validated_mode"] == "advertisement_only_local_mesh"

    assert "passive BLE advertisement observations" in snapshot["release_scope"][
             "allowed_release_wording"
           ]

    assert "trusted_delivery" in snapshot["release_scope"]["blocked_release_wording"]

    assert "operator_release_note_review" in snapshot["release_scope"][
             "required_before_release_candidate_complete"
           ]
  end

  test "required command gates stay in sync with generated artifact sources" do
    source_commands =
      LocalReleaseArtifactBundle.artifacts()
      |> Enum.map(& &1.source)
      |> Enum.filter(&String.starts_with?(&1, "mix "))

    snapshot = LocalReleaseArtifactBundle.snapshot()

    assert snapshot.required_commands == source_commands
    assert snapshot.required_commands == Enum.uniq(snapshot.required_commands)
  end

  test "completion blocker matrix is generated as a release planning artifact" do
    artifact =
      LocalReleaseArtifactBundle.artifacts()
      |> Enum.find(&(&1.id == :completion_blocker_matrix))

    assert artifact.status == :generated
    assert artifact.path == "tmp/local-completion-blocker-matrix.json"
    assert :completion_review in artifact.required_for
    assert :release_planning in artifact.required_for
    assert :whole_project_complete in artifact.blocked_claims
    assert :hardware_complete in artifact.blocked_claims

    assert Enum.any?(
             artifact.acceptance_criteria,
             &String.contains?(&1, "Hardware-blocked objectives")
           )

    assert Enum.any?(
             artifact.acceptance_criteria,
             &String.contains?(&1, "HARDWARE_BLOCKED")
           )

    assert Enum.any?(
             artifact.acceptance_criteria,
             &String.contains?(&1, "NO_NEW_HARDWARE")
           )
  end

  test "standalone completion audit artifact requires prompt checklist review" do
    artifact =
      LocalReleaseArtifactBundle.artifacts()
      |> Enum.find(&(&1.id == :completion_audit_standalone))

    assert artifact.status == :generated
    assert :completion_review in artifact.required_for
    assert :release_planning in artifact.required_for
    assert :whole_project_complete in artifact.blocked_claims

    assert Enum.any?(
             artifact.acceptance_criteria,
             &String.contains?(&1, "Prompt artifact checklist maps every objective")
           )

    assert Enum.any?(
             artifact.acceptance_criteria,
             &String.contains?(&1, "ordered objective IDs")
           )
  end

  test "plain-text completion audit review keeps open objectives visible" do
    artifact =
      LocalReleaseArtifactBundle.artifacts()
      |> Enum.find(&(&1.id == :completion_audit_plain_text_review))

    assert artifact.status == :generated
    assert artifact.path == "tmp/local-completion-audit.txt"

    assert artifact.source ==
             "mix meshx.mobile.local_completion.audit --allow-open | tee tmp/local-completion-audit.txt"

    assert :completion_review in artifact.required_for
    assert :operator_release_review in artifact.required_for
    assert :whole_project_complete in artifact.blocked_claims

    assert Enum.any?(
             artifact.acceptance_criteria,
             &String.contains?(&1, "archived beside the JSON completion audit")
           )

    assert Enum.any?(artifact.acceptance_criteria, &String.contains?(&1, "OPEN_ITEMS 10"))

    assert Enum.any?(
             artifact.acceptance_criteria,
             &String.contains?(&1, "OPEN_ITEM objective=... status=... missing=...")
           )
  end

  test "hardware log bundle remains open and blocks unproven hardware claims" do
    artifact =
      LocalReleaseArtifactBundle.open_artifacts()
      |> Enum.find(&(&1.id == :hardware_log_bundle))

    assert artifact.status == :operator_supplied_open
    assert :hardware_claims in artifact.required_for
    assert :full_message_resolution in artifact.blocked_claims
    assert :multi_hop_hardware_delivery in artifact.blocked_claims

    assert Enum.any?(
             artifact.acceptance_criteria,
             &String.contains?(&1, "device model")
           )

    assert Enum.any?(
             artifact.acceptance_criteria,
             &String.contains?(&1, "LocalReleaseCandidateEvidenceReview")
           )

    assert Enum.any?(
             artifact.acceptance_criteria,
             &String.contains?(&1, "2026-05-13-sm-t577u-sm-t390")
           )
  end

  test "recent evidence inventory is generated but does not complete release claims" do
    artifact =
      LocalReleaseArtifactBundle.artifacts()
      |> Enum.find(&(&1.id == :recent_evidence_inventory))

    assert artifact.status == :generated
    assert :release_planning in artifact.required_for
    assert :operator_release_review in artifact.required_for
    assert :whole_project_complete in artifact.blocked_claims
    assert :full_message_resolution in artifact.blocked_claims
    assert String.contains?(artifact.source, "local_release.recent_evidence")

    assert Enum.any?(
             artifact.acceptance_criteria,
             &String.contains?(&1, "objective-specific review")
           )
  end

  test "operator release notes constrain wording to advert-only local mode" do
    template =
      LocalReleaseArtifactBundle.open_artifacts()
      |> Enum.find(&(&1.id == :release_candidate_evidence_template))

    assert template.status == :operator_supplied_open
    assert :operator_release_review in template.required_for
    assert :whole_project_complete in template.blocked_claims

    assert Enum.any?(
             template.acceptance_criteria,
             &String.contains?(&1, "UX review summary")
           )

    assert Enum.any?(
             template.acceptance_criteria,
             &String.contains?(&1, "coverage summary")
           )

    assert Enum.any?(
             template.acceptance_criteria,
             &String.contains?(&1, "UX review output")
           )

    artifact =
      LocalReleaseArtifactBundle.open_artifacts()
      |> Enum.find(&(&1.id == :operator_release_notes))

    assert artifact.status == :open
    assert :operator_release_review in artifact.required_for
    assert :guaranteed_delivery in artifact.blocked_claims
    assert :ios_parity in artifact.blocked_claims

    assert Enum.any?(
             artifact.acceptance_criteria,
             &String.contains?(&1, "messages seen nearby")
           )

    assert Enum.any?(
             artifact.acceptance_criteria,
             &String.contains?(&1, "JSON completion audit")
           )

    assert Enum.any?(
             artifact.acceptance_criteria,
             &String.contains?(&1, "plain-text completion audit")
           )

    assert Enum.any?(
             artifact.acceptance_criteria,
             &String.contains?(&1, "blocker matrix")
           )

    assert Enum.any?(
             artifact.acceptance_criteria,
             &String.contains?(&1, "ready UX review")
           )

    assert Enum.any?(
             artifact.acceptance_criteria,
             &String.contains?(&1, "blocked-claim")
           )
  end

  test "security evidence manifest keeps authenticated and trusted claims blocked" do
    validation_plan =
      LocalReleaseArtifactBundle.artifacts()
      |> Enum.find(&(&1.id == :security_validation_plan))

    assert validation_plan.status == :generated
    assert :security_evidence_review in validation_plan.required_for
    assert :authenticated_peer_identity in validation_plan.blocked_claims
    assert :trusted_delivery in validation_plan.blocked_claims
    assert String.contains?(validation_plan.source, "local_security.validation_plan")

    assert Enum.any?(
             validation_plan.acceptance_criteria,
             &String.contains?(&1, "beacon authentication")
           )

    artifact =
      LocalReleaseArtifactBundle.artifacts()
      |> Enum.find(&(&1.id == :security_evidence_manifest))

    assert artifact.status == :generated
    assert :security_evidence_review in artifact.required_for
    assert :authenticated_message in artifact.blocked_claims
    assert :trusted_delivery in artifact.blocked_claims

    assert Enum.any?(
             artifact.acceptance_criteria,
             &String.contains?(&1, "security_evidence_complete?")
           )
  end

  test "security release evidence review is operator-supplied and keeps trust blocked" do
    artifact =
      LocalReleaseArtifactBundle.artifacts()
      |> Enum.find(&(&1.id == :security_release_evidence_review))

    assert artifact.status == :operator_supplied_open
    assert :security_evidence_review in artifact.required_for
    assert :authenticated_peer_identity in artifact.blocked_claims
    assert :trusted_message in artifact.blocked_claims
    assert :trusted_delivery in artifact.blocked_claims
    assert :fresh_message in artifact.blocked_claims
    assert String.contains?(artifact.source, "--template")

    assert Enum.any?(
             artifact.acceptance_criteria,
             &String.contains?(&1, "metadata scaffold")
           )

    assert Enum.any?(
             artifact.acceptance_criteria,
             &String.contains?(&1, "LocalSecurityIdentityValidationPlan")
           )
  end

  test "UX evidence manifest keeps production UX and delivery claims blocked" do
    validation_plan =
      LocalReleaseArtifactBundle.artifacts()
      |> Enum.find(&(&1.id == :ux_validation_plan))

    assert validation_plan.status == :generated
    assert :product_ux_review in validation_plan.required_for
    assert :production_nearby_messages_ux in validation_plan.blocked_claims
    assert String.contains?(validation_plan.source, "ux_validation_plan")

    assert Enum.any?(
             validation_plan.acceptance_criteria,
             &(String.contains?(&1, "Target-device matrix") and
                 String.contains?(&1, "selected-detail coverage"))
           )

    artifact =
      LocalReleaseArtifactBundle.artifacts()
      |> Enum.find(&(&1.id == :ux_evidence_manifest))

    assert artifact.status == :generated
    assert :product_ux_review in artifact.required_for
    assert :production_nearby_messages_ux in artifact.blocked_claims
    assert :trusted_delivery in artifact.blocked_claims

    assert Enum.any?(
             artifact.acceptance_criteria,
             &String.contains?(&1, "Full, unresolved, gossiped, and stale states")
           )

    assert Enum.any?(
             artifact.acceptance_criteria,
             &String.contains?(&1, "Selected-detail evidence")
           )

    assert Enum.any?(
             artifact.acceptance_criteria,
             &String.contains?(&1, "Per-row blocked-claim copy")
           )
  end

  test "UX decision scenario plan is embedded as a product UX artifact" do
    artifact =
      LocalReleaseArtifactBundle.artifacts()
      |> Enum.find(&(&1.id == :ux_decision_scenario_plan))

    assert artifact.status == :embedded
    assert artifact.path == "tmp/local-inbox-ux-evidence.json#/ux_decision_scenario_plan"
    assert :product_ux_review in artifact.required_for
    assert :production_nearby_messages_ux in artifact.blocked_claims
    assert :delivery in artifact.blocked_claims
    assert :trusted_delivery in artifact.blocked_claims
    assert :routing in artifact.blocked_claims

    assert Enum.any?(
             artifact.acceptance_criteria,
             &String.contains?(&1, "promote_nearby_messages_production_ux")
           )

    assert Enum.any?(
             artifact.acceptance_criteria,
             &String.contains?(&1, "LocalInboxUxValidationPlan")
           )
  end

  test "UX evidence review is an operator-supplied product UX artifact" do
    template =
      LocalReleaseArtifactBundle.artifacts()
      |> Enum.find(&(&1.id == :ux_evidence_template))

    assert template.status == :operator_supplied_open
    assert :product_ux_review in template.required_for
    assert :production_nearby_messages_ux in template.blocked_claims
    assert :trusted_delivery in template.blocked_claims
    assert :routing in template.blocked_claims
    assert String.contains?(template.source, "--template")

    assert Enum.any?(
             template.acceptance_criteria,
             &String.contains?(&1, "selected_detail_evidence")
           )

    assert Enum.any?(
             template.acceptance_criteria,
             &(String.contains?(&1, "limitation_copy") and
                 String.contains?(&1, "next_action_copy") and
                 String.contains?(&1, "blocked_claim_copy"))
           )

    assert Enum.any?(
             template.acceptance_criteria,
             &(String.contains?(&1, "State") and
                 String.contains?(&1, "interaction") and
                 String.contains?(&1, "copy-review") and
                 String.contains?(&1, "visual-density") and
                 String.contains?(&1, "evidence_kind"))
           )

    assert Enum.any?(
             template.acceptance_criteria,
             &String.contains?(&1, "evidence_kind")
           )

    artifact =
      LocalReleaseArtifactBundle.artifacts()
      |> Enum.find(&(&1.id == :ux_evidence_review))

    assert artifact.status == :operator_supplied_open
    assert :product_ux_review in artifact.required_for
    assert :trusted_delivery in artifact.blocked_claims
    assert :routing in artifact.blocked_claims
    assert String.contains?(artifact.source, "--input")
    refute String.contains?(artifact.source, "--template")

    assert Enum.any?(
             artifact.acceptance_criteria,
             &String.contains?(&1, "metadata scaffold is completed")
           )

    assert Enum.any?(
             artifact.acceptance_criteria,
             &String.contains?(&1, "Full, unresolved, gossiped, and stale states")
           )

    assert Enum.any?(
             artifact.acceptance_criteria,
             &String.contains?(&1, "control-summary copy")
           )

    assert Enum.any?(
             artifact.acceptance_criteria,
             &String.contains?(&1, "selected_detail_evidence")
           )

    assert Enum.any?(
             artifact.acceptance_criteria,
             &(String.contains?(&1, "limitation_copy") and
                 String.contains?(&1, "next_action_copy") and
                 String.contains?(&1, "blocked_claim_copy"))
           )

    assert Enum.any?(
             artifact.acceptance_criteria,
             &(String.contains?(&1, "interaction_evidence") and
                 String.contains?(&1, "evidence_kind"))
           )

    assert Enum.any?(
             artifact.acceptance_criteria,
             &(String.contains?(&1, "copy_review with evidence_kind") and
                 String.contains?(&1, "visual_density_review with evidence_kind"))
           )

    assert Enum.any?(
             artifact.acceptance_criteria,
             &String.contains?(&1, "coverage_summary selected-detail coverage")
           )

    assert Enum.any?(
             artifact.acceptance_criteria,
             &String.contains?(&1, "per-state blocked-claim copy")
           )
  end

  test "full message resolution evidence manifest keeps real transport claims blocked" do
    artifact =
      LocalReleaseArtifactBundle.artifacts()
      |> Enum.find(&(&1.id == :full_message_resolution_evidence_manifest))

    assert artifact.status == :generated
    assert :full_message_resolution_review in artifact.required_for
    assert :known_good_transport_review in artifact.required_for
    assert :full_message_resolution in artifact.blocked_claims
    assert :known_good_transport in artifact.blocked_claims
    assert :gatt_fetch_success in artifact.blocked_claims
    assert :message_delivery in artifact.blocked_claims

    assert Enum.any?(
             artifact.acceptance_criteria,
             &String.contains?(&1, "real_fetch_transport_validated?")
           )
  end

  test "full resolution transport evidence review is operator-supplied and keeps resolution blocked" do
    artifact =
      LocalReleaseArtifactBundle.artifacts()
      |> Enum.find(&(&1.id == :full_resolution_transport_evidence_review))

    assert artifact.status == :operator_supplied_open
    assert :full_message_resolution_review in artifact.required_for
    assert :known_good_transport_review in artifact.required_for
    assert :full_message_resolution in artifact.blocked_claims
    assert :known_good_transport in artifact.blocked_claims
    assert :message_delivery in artifact.blocked_claims
    assert :fake_success in artifact.blocked_claims

    assert Enum.any?(
             artifact.acceptance_criteria,
             &String.contains?(&1, "Current GATT blocker")
           )
  end

  test "known-good transport evidence review is operator-supplied and keeps transport blocked" do
    artifact =
      LocalReleaseArtifactBundle.artifacts()
      |> Enum.find(&(&1.id == :known_good_transport_evidence_review))

    assert artifact.status == :operator_supplied_open
    assert :known_good_transport_review in artifact.required_for
    assert :known_good_transport in artifact.blocked_claims
    assert :transport_validated in artifact.blocked_claims
    assert :gatt_fetch_success in artifact.blocked_claims
    assert :full_message_resolution in artifact.blocked_claims

    assert Enum.any?(
             artifact.acceptance_criteria,
             &String.contains?(&1, "Candidate transport decision")
           )

    assert Enum.any?(
             artifact.acceptance_criteria,
             &String.contains?(&1, "GATT status 133")
           )

    assert Enum.any?(
             artifact.acceptance_criteria,
             &String.contains?(&1, "2026-05-13-sm-t577u-sm-t390")
           )
  end

  test "persistence evidence manifest keeps default persistence and delivery claims blocked" do
    lifecycle_plan =
      LocalReleaseArtifactBundle.artifacts()
      |> Enum.find(&(&1.id == :production_persistence_lifecycle_plan))

    assert lifecycle_plan.status == :generated
    assert :persistence_review in lifecycle_plan.required_for
    assert :default_app_persistence in lifecycle_plan.blocked_claims
    assert :delivery_record in lifecycle_plan.blocked_claims
    assert String.contains?(lifecycle_plan.source, "local_persistence.lifecycle_plan")

    assert Enum.any?(
             lifecycle_plan.acceptance_criteria,
             &String.contains?(&1, "schema migration")
           )

    artifact =
      LocalReleaseArtifactBundle.artifacts()
      |> Enum.find(&(&1.id == :persistence_evidence_manifest))

    assert artifact.status == :generated
    assert :persistence_review in artifact.required_for
    assert :default_app_persistence in artifact.blocked_claims
    assert :delivery_record in artifact.blocked_claims
    assert :full_message_resolution in artifact.blocked_claims

    assert Enum.any?(
             artifact.acceptance_criteria,
             &String.contains?(&1, "current_default_mode")
           )
  end

  test "production persistence evidence review is operator-supplied and keeps defaults blocked" do
    artifact =
      LocalReleaseArtifactBundle.artifacts()
      |> Enum.find(&(&1.id == :production_persistence_evidence_review))

    assert artifact.status == :operator_supplied_open
    assert :persistence_review in artifact.required_for
    assert :default_app_persistence in artifact.blocked_claims
    assert :delivery_record in artifact.blocked_claims
    assert :trusted_message_delivery in artifact.blocked_claims
    assert String.contains?(artifact.source, "--template")

    assert Enum.any?(
             artifact.acceptance_criteria,
             &String.contains?(&1, "metadata scaffold")
           )

    assert Enum.any?(
             artifact.acceptance_criteria,
             &String.contains?(&1, "Product decision, schema migration")
           )
  end

  test "lifecycle validation plan and evidence manifest keep background lifecycle claims blocked" do
    validation_artifact =
      LocalReleaseArtifactBundle.artifacts()
      |> Enum.find(&(&1.id == :lifecycle_validation_plan))

    assert validation_artifact.status == :generated
    assert :lifecycle_review in validation_artifact.required_for
    assert :android_foreground_service_ble in validation_artifact.blocked_claims
    assert :ios_background_scan in validation_artifact.blocked_claims
    assert :scheduled_retry in validation_artifact.blocked_claims
    assert :background_delivery in validation_artifact.blocked_claims
    assert String.contains?(validation_artifact.source, "local_lifecycle.validation_plan")

    assert Enum.any?(
             validation_artifact.acceptance_criteria,
             &String.contains?(&1, "Android foreground-service")
           )

    artifact =
      LocalReleaseArtifactBundle.artifacts()
      |> Enum.find(&(&1.id == :lifecycle_evidence_manifest))

    assert artifact.status == :generated
    assert :lifecycle_review in artifact.required_for
    assert :android_foreground_service_ble in artifact.blocked_claims
    assert :ios_background_scan in artifact.blocked_claims
    assert :automatic_ble_restart in artifact.blocked_claims
    assert :background_delivery in artifact.blocked_claims

    assert Enum.any?(
             artifact.acceptance_criteria,
             &String.contains?(&1, "current_mode")
           )

    scenario_plan =
      LocalReleaseArtifactBundle.artifacts()
      |> Enum.find(&(&1.id == :lifecycle_decision_scenario_plan))

    assert scenario_plan.status == :embedded

    assert scenario_plan.source ==
             "LocalLifecycleEvidenceManifest.snapshot().lifecycle_decision_scenario_plan"

    assert :lifecycle_review in scenario_plan.required_for
    assert :android_foreground_service_ble in scenario_plan.blocked_claims
    assert :ios_background_scan in scenario_plan.blocked_claims
    assert :automatic_ble_restart in scenario_plan.blocked_claims
    assert :background_delivery in scenario_plan.blocked_claims

    assert Enum.any?(
             scenario_plan.acceptance_criteria,
             &String.contains?(&1, "keep_foreground_manual")
           )
  end

  test "lifecycle hardware evidence review is operator-supplied and keeps background blocked" do
    artifact =
      LocalReleaseArtifactBundle.artifacts()
      |> Enum.find(&(&1.id == :lifecycle_hardware_evidence_review))

    assert artifact.status == :operator_supplied_open
    assert :lifecycle_review in artifact.required_for
    assert :android_foreground_service_ble in artifact.blocked_claims
    assert :ios_background_scan in artifact.blocked_claims
    assert :automatic_ble_restart in artifact.blocked_claims
    assert :background_delivery in artifact.blocked_claims

    assert Enum.any?(
             artifact.acceptance_criteria,
             &String.contains?(&1, "Target device, Android foreground service")
           )
  end

  test "multi-hop hardware evidence manifest keeps replay and one-hop evidence distinct" do
    artifact =
      LocalReleaseArtifactBundle.artifacts()
      |> Enum.find(&(&1.id == :multi_hop_hardware_evidence_manifest))

    assert artifact.status == :generated
    assert :multi_hop_hardware_review in artifact.required_for
    assert :multi_hop_hardware_gossip in artifact.blocked_claims
    assert :multi_hop_hardware_delivery in artifact.blocked_claims
    assert :routed_delivery in artifact.blocked_claims
    assert :guaranteed_delivery in artifact.blocked_claims

    assert Enum.any?(
             artifact.acceptance_criteria,
             &String.contains?(&1, "Replay fixture evidence remains separate")
           )
  end

  test "multi-hop hardware evidence review is operator-supplied and keeps multi-hop claims blocked" do
    artifact =
      LocalReleaseArtifactBundle.artifacts()
      |> Enum.find(&(&1.id == :multi_hop_hardware_evidence_review))

    assert artifact.status == :operator_supplied_open
    assert :multi_hop_hardware_review in artifact.required_for
    assert :multi_hop_hardware_gossip in artifact.blocked_claims
    assert :multi_hop_hardware_delivery in artifact.blocked_claims
    assert :routed_delivery in artifact.blocked_claims
    assert :background_operation in artifact.blocked_claims
    assert :whole_project_complete in artifact.blocked_claims

    assert Enum.any?(
             artifact.acceptance_criteria,
             &String.contains?(&1, "Three-role device matrix")
           )
  end

  test "iOS parity evidence manifest keeps iOS participation claims blocked" do
    artifact =
      LocalReleaseArtifactBundle.artifacts()
      |> Enum.find(&(&1.id == :ios_parity_evidence_manifest))

    assert artifact.status == :generated
    assert :ios_parity_review in artifact.required_for
    assert :ios_hardware_participation in artifact.blocked_claims
    assert :ios_legacy_beacon_observed in artifact.blocked_claims
    assert :ios_legacy_beacon_gossip in artifact.blocked_claims
    assert :ios_parity_claim in artifact.blocked_claims

    assert Enum.any?(
             artifact.acceptance_criteria,
             &String.contains?(&1, "current_ios_mode")
           )

    scenario_plan =
      LocalReleaseArtifactBundle.artifacts()
      |> Enum.find(&(&1.id == :ios_parity_decision_scenario_plan))

    assert scenario_plan.status == :embedded

    assert scenario_plan.source ==
             "LocalIOSParityEvidenceManifest.snapshot().ios_parity_decision_scenario_plan"

    assert :ios_parity_review in scenario_plan.required_for
    assert :ios_hardware_participation in scenario_plan.blocked_claims
    assert :ios_legacy_beacon_gossip in scenario_plan.blocked_claims
    assert :ios_parity_claim in scenario_plan.blocked_claims

    assert Enum.any?(
             scenario_plan.acceptance_criteria,
             &String.contains?(&1, "keep_ios_contract_only")
           )
  end

  test "iOS parity hardware evidence review is operator-supplied and keeps iOS claims blocked" do
    artifact =
      LocalReleaseArtifactBundle.artifacts()
      |> Enum.find(&(&1.id == :ios_parity_hardware_evidence_review))

    assert artifact.status == :operator_supplied_open
    assert :ios_parity_review in artifact.required_for
    assert :ios_hardware_participation in artifact.blocked_claims
    assert :ios_legacy_beacon_observed in artifact.blocked_claims
    assert :ios_full_envelope_advert in artifact.blocked_claims
    assert :ios_background_ble in artifact.blocked_claims
    assert :ios_parity_claim in artifact.blocked_claims

    assert Enum.any?(
             artifact.acceptance_criteria,
             &String.contains?(&1, "iOS target device")
           )
  end

  test "routing evidence manifest keeps route selection forwarding and delivery blocked" do
    validation_plan =
      LocalReleaseArtifactBundle.artifacts()
      |> Enum.find(&(&1.id == :routing_validation_plan))

    assert validation_plan.status == :generated
    assert :routing_review in validation_plan.required_for
    assert :route_selection_available in validation_plan.blocked_claims
    assert :routed_delivery in validation_plan.blocked_claims
    assert String.contains?(validation_plan.source, "local_routing.validation_plan")

    assert Enum.any?(
             validation_plan.acceptance_criteria,
             &String.contains?(&1, "deterministic selection")
           )

    artifact =
      LocalReleaseArtifactBundle.artifacts()
      |> Enum.find(&(&1.id == :routing_evidence_manifest))

    assert artifact.status == :generated
    assert :routing_review in artifact.required_for
    assert :route_selection_available in artifact.blocked_claims
    assert :live_forwarding_service in artifact.blocked_claims
    assert :routed_delivery in artifact.blocked_claims
    assert :multi_hop_hardware_routing in artifact.blocked_claims

    assert Enum.any?(
             artifact.acceptance_criteria,
             &String.contains?(&1, "Route candidates remain read-model entries")
           )

    scenario_plan =
      LocalReleaseArtifactBundle.artifacts()
      |> Enum.find(&(&1.id == :routing_decision_scenario_plan))

    assert scenario_plan.status == :embedded

    assert scenario_plan.source ==
             "LocalRoutingEvidenceManifest.snapshot().routing_decision_scenario_plan"

    assert :routing_review in scenario_plan.required_for
    assert :route_selection_available in scenario_plan.blocked_claims
    assert :live_forwarding_service in scenario_plan.blocked_claims
    assert :routed_delivery in scenario_plan.blocked_claims

    assert Enum.any?(
             scenario_plan.acceptance_criteria,
             &String.contains?(&1, "keep_advert_only_non_routing")
           )
  end

  test "production routing evidence review is operator-supplied and keeps routing blocked" do
    artifact =
      LocalReleaseArtifactBundle.artifacts()
      |> Enum.find(&(&1.id == :production_routing_evidence_review))

    assert artifact.status == :operator_supplied_open
    assert :routing_review in artifact.required_for
    assert :route_selection_available in artifact.blocked_claims
    assert :live_forwarding_service in artifact.blocked_claims
    assert :routed_delivery in artifact.blocked_claims
    assert :multi_hop_hardware_routing in artifact.blocked_claims

    assert Enum.any?(
             artifact.acceptance_criteria,
             &String.contains?(&1, "Route table, route selection, forwarding")
           )
  end

  test "release manifest embeds the artifact bundle checklist" do
    manifest = LocalReleaseManifest.snapshot()

    refute manifest.artifact_bundle.release_candidate_complete?
    assert manifest.artifact_bundle.artifact_count == 49
    assert manifest.artifact_bundle.open_artifact_count == 19
    assert Enum.any?(manifest.required_artifacts, &(&1.id == :artifact_bundle_checklist))

    assert Enum.any?(
             manifest.artifact_bundle.artifacts,
             &(&1.id == :full_message_resolution_evidence_manifest)
           )

    assert Enum.any?(
             manifest.artifact_bundle.artifacts,
             &(&1.id == :full_resolution_transport_evidence_review)
           )

    assert Enum.any?(
             manifest.artifact_bundle.artifacts,
             &(&1.id == :known_good_transport_evidence_review)
           )

    assert Enum.any?(manifest.artifact_bundle.artifacts, &(&1.id == :ux_evidence_manifest))
    assert Enum.any?(manifest.artifact_bundle.artifacts, &(&1.id == :ux_decision_scenario_plan))
    assert Enum.any?(manifest.artifact_bundle.artifacts, &(&1.id == :ux_evidence_template))
    assert Enum.any?(manifest.artifact_bundle.artifacts, &(&1.id == :ux_evidence_review))

    assert Enum.any?(
             manifest.artifact_bundle.artifacts,
             &(&1.id == :ios_parity_evidence_manifest)
           )

    assert Enum.any?(
             manifest.artifact_bundle.artifacts,
             &(&1.id == :ios_parity_decision_scenario_plan)
           )

    assert Enum.any?(
             manifest.artifact_bundle.artifacts,
             &(&1.id == :ios_parity_operator_capture_plan)
           )

    assert Enum.any?(
             manifest.artifact_bundle.artifacts,
             &(&1.id == :ios_parity_hardware_evidence_review)
           )

    assert Enum.any?(manifest.artifact_bundle.artifacts, &(&1.id == :lifecycle_validation_plan))

    assert Enum.any?(manifest.artifact_bundle.artifacts, &(&1.id == :lifecycle_evidence_manifest))

    assert Enum.any?(
             manifest.artifact_bundle.artifacts,
             &(&1.id == :lifecycle_decision_scenario_plan)
           )

    assert Enum.any?(
             manifest.artifact_bundle.artifacts,
             &(&1.id == :lifecycle_hardware_evidence_review)
           )

    assert Enum.any?(
             manifest.artifact_bundle.artifacts,
             &(&1.id == :multi_hop_hardware_evidence_manifest)
           )

    assert Enum.any?(
             manifest.artifact_bundle.artifacts,
             &(&1.id == :multi_hop_hardware_evidence_review)
           )

    assert Enum.any?(
             manifest.artifact_bundle.artifacts,
             &(&1.id == :production_persistence_lifecycle_plan)
           )

    assert Enum.any?(
             manifest.artifact_bundle.artifacts,
             &(&1.id == :persistence_evidence_manifest)
           )

    assert Enum.any?(
             manifest.artifact_bundle.artifacts,
             &(&1.id == :production_persistence_evidence_review)
           )

    assert Enum.any?(
             manifest.artifact_bundle.artifacts,
             &(&1.id == :routing_validation_plan)
           )

    assert Enum.any?(
             manifest.artifact_bundle.artifacts,
             &(&1.id == :routing_evidence_manifest)
           )

    assert Enum.any?(
             manifest.artifact_bundle.artifacts,
             &(&1.id == :routing_decision_scenario_plan)
           )

    assert Enum.any?(
             manifest.artifact_bundle.artifacts,
             &(&1.id == :production_routing_evidence_review)
           )

    assert Enum.any?(
             manifest.artifact_bundle.artifacts,
             &(&1.id == :security_validation_plan)
           )

    assert Enum.any?(manifest.artifact_bundle.artifacts, &(&1.id == :security_evidence_manifest))

    assert Enum.any?(
             manifest.artifact_bundle.artifacts,
             &(&1.id == :security_operator_capture_plan)
           )

    assert Enum.any?(
             manifest.artifact_bundle.artifacts,
             &(&1.id == :security_release_evidence_review)
           )

    assert Enum.any?(
             manifest.artifact_bundle.artifacts,
             &(&1.id == :recent_evidence_inventory)
           )

    assert Enum.any?(
             manifest.artifact_bundle.artifacts,
             &(&1.id == :release_operator_capture_plan)
           )
  end

  test "json snapshot is machine readable" do
    snapshot = LocalReleaseArtifactBundle.json_snapshot()

    assert snapshot["bundle_version"] == 1
    assert snapshot["release_candidate_complete?"] == false
    assert snapshot["artifact_count"] == 49
    assert snapshot["open_artifact_count"] == 19
    assert length(snapshot["required_commands"]) == 37

    assert Enum.any?(
             snapshot["artifacts"],
             &(&1["id"] == "hardware_log_bundle" and &1["status"] == "operator_supplied_open")
           )
  end
end
