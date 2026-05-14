defmodule MeshxMobileApp.BLE.LocalProjectCompletionAuditTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.LocalProjectCompletionAudit

  test "snapshot keeps whole-project completion explicitly blocked" do
    audit = LocalProjectCompletionAudit.snapshot()

    assert audit.audit_version == 1
    assert audit.objective == :whole_project_completion
    assert audit.current_validated_mode == :advertisement_only_local_mesh
    refute audit.whole_project_complete?
    refute audit.completion_claim_allowed?
    assert audit.open_item_count == 10
    assert audit.blocked_item_count == 3
    assert audit.partial_item_count == 7
    assert audit.not_started_item_count == 0
    assert audit.blocker_matrix.boundary == :whole_project_completion_blocker_matrix
    assert audit.blocker_matrix.primary_blocker_counts.hardware_evidence == 3
  end

  test "completion counts match blocker matrix entry statuses" do
    audit = LocalProjectCompletionAudit.snapshot()
    counts = Enum.frequencies_by(audit.blocker_matrix.entries, & &1.status)

    assert audit.open_item_count == length(audit.blocker_matrix.entries)
    assert audit.blocked_item_count == Map.get(counts, :blocked, 0)
    assert audit.partial_item_count == Map.get(counts, :partial, 0)
    assert audit.not_started_item_count == Map.get(counts, :not_started, 0)
  end

  test "completion claim stays blocked while any objective remains open" do
    audit = LocalProjectCompletionAudit.snapshot()

    has_open_work? =
      audit.blocked_item_count > 0 or
        audit.partial_item_count > 0 or
        audit.not_started_item_count > 0

    assert has_open_work?
    refute audit.whole_project_complete?
    refute audit.completion_claim_allowed?
  end

  test "audit maps every objective item to readiness status and missing evidence" do
    audit = LocalProjectCompletionAudit.snapshot()
    ids = Enum.map(audit.items, & &1.objective_id)

    assert :full_message_resolution in ids
    assert :known_good_transport_validation in ids
    assert :multi_hop_hardware_proof in ids
    assert :product_ux in ids
    assert :persistence in ids
    assert :security_identity in ids
    assert :routing in ids
    assert :background_mobile_lifecycle in ids
    assert :ios_parity in ids
    assert :release_hardening in ids

    full_resolution = Enum.find(audit.items, &(&1.objective_id == :full_message_resolution))

    assert full_resolution.status == :blocked
    refute full_resolution.completion_claim_allowed?

    assert Enum.any?(
             full_resolution.missing_evidence,
             &String.contains?(&1, "Real transport proof")
           )

    assert Enum.any?(
             full_resolution.required_artifacts,
             &String.contains?(&1, "BeaconFetchRequest")
           )

    assert Enum.any?(
             full_resolution.required_artifacts,
             &String.contains?(&1, "LocalFetchTransportValidationPlan")
           )

    assert Enum.any?(
             full_resolution.required_artifacts,
             &String.contains?(&1, "LocalFullMessageResolutionEvidenceManifest")
           )

    assert Enum.any?(
             full_resolution.missing_evidence,
             &String.contains?(&1, "LocalFetchTransportValidationPlan")
           )

    known_good = Enum.find(audit.items, &(&1.objective_id == :known_good_transport_validation))

    assert known_good.status == :blocked

    assert Enum.any?(
             known_good.required_artifacts,
             &String.contains?(&1, "LocalFetchTransportValidationPlan")
           )

    assert Enum.any?(
             known_good.required_artifacts,
             &String.contains?(&1, "LocalFullMessageResolutionEvidenceManifest")
           )

    assert Enum.any?(
             known_good.required_artifacts,
             &String.contains?(&1, "LocalKnownGoodTransportEvidenceReview")
           )

    assert Enum.any?(
             known_good.missing_evidence,
             &String.contains?(&1, "LocalFetchTransportValidationPlan")
           )

    multi_hop = Enum.find(audit.items, &(&1.objective_id == :multi_hop_hardware_proof))

    assert multi_hop.status == :blocked

    assert Enum.any?(
             multi_hop.required_artifacts,
             &String.contains?(&1, "LocalAdvertGossipHardwareValidationPlan")
           )

    assert Enum.any?(
             multi_hop.required_artifacts,
             &String.contains?(&1, "LocalMultiHopHardwareEvidenceManifest")
           )

    assert Enum.any?(
             multi_hop.missing_evidence,
             &String.contains?(&1, "LocalAdvertGossipHardwareValidationPlan")
           )

    product_ux = Enum.find(audit.items, &(&1.objective_id == :product_ux))

    assert product_ux.status == :partial

    assert Enum.any?(
             product_ux.current_evidence,
             &String.contains?(&1, "Mob Nearby Messages controls")
           )

    assert Enum.any?(
             product_ux.required_artifacts,
             &String.contains?(&1, "Centralized state copy")
           )

    assert Enum.any?(
             product_ux.required_artifacts,
             &String.contains?(&1, "summary line")
           )

    assert Enum.any?(
             product_ux.required_artifacts,
             &String.contains?(&1, "LocalInboxUxAcceptance")
           )

    assert Enum.any?(
             product_ux.required_artifacts,
             &String.contains?(&1, "control summaries")
           )

    assert Enum.any?(
             product_ux.required_artifacts,
             &String.contains?(&1, "selected detail evidence")
           )

    assert Enum.any?(
             product_ux.required_artifacts,
             &String.contains?(&1, "coverage_summary")
           )

    assert Enum.any?(
             product_ux.required_artifacts,
             &String.contains?(&1, "blocked_claim_copy")
           )

    assert Enum.any?(
             product_ux.required_artifacts,
             &String.contains?(&1, "limitation_copy")
           )

    assert Enum.any?(
             product_ux.required_artifacts,
             &String.contains?(&1, "next_action_copy")
           )

    assert Enum.any?(
             product_ux.required_artifacts,
             &String.contains?(&1, "LocalInboxUxValidationPlan")
           )

    assert Enum.any?(
             product_ux.required_artifacts,
             &String.contains?(&1, "LocalInboxUxOperatorCapturePlan")
           )

    assert Enum.any?(
             product_ux.required_artifacts,
             &String.contains?(&1, "LocalInboxUxTargetDeviceScenarioPlan")
           )

    assert Enum.any?(
             product_ux.required_artifacts,
             &String.contains?(&1, "LocalInboxUxDecisionScenarioPlan")
           )

    assert Enum.any?(
             product_ux.required_artifacts,
             &String.contains?(&1, "evidence_kind classified")
           )

    assert Enum.any?(
             product_ux.missing_evidence,
             &String.contains?(&1, "LocalInboxUxAcceptance on-device validation")
           )

    assert Enum.any?(
             product_ux.missing_evidence,
             &String.contains?(&1, "LocalInboxUxValidationPlan")
           )

    assert Enum.any?(
             product_ux.missing_evidence,
             &String.contains?(&1, "evidence_kind classification")
           )

    assert Enum.any?(
             product_ux.missing_evidence,
             &String.contains?(&1, "limitation_copy")
           )

    assert Enum.any?(
             product_ux.missing_evidence,
             &String.contains?(&1, "next_action_copy")
           )

    assert Enum.any?(
             product_ux.missing_evidence,
             &String.contains?(&1, "blocked_claim_copy")
           )

    assert Enum.any?(
             product_ux.missing_evidence,
             &String.contains?(&1, "On-device UX validation")
           )

    persistence = Enum.find(audit.items, &(&1.objective_id == :persistence))

    assert persistence.status == :partial

    assert Enum.any?(
             persistence.required_artifacts,
             &String.contains?(&1, "decision_outcome keep_memory_only_default")
           )

    assert Enum.any?(
             persistence.required_artifacts,
             &String.contains?(&1, "LocalPersistenceAcceptance")
           )

    assert Enum.any?(
             persistence.required_artifacts,
             &String.contains?(&1, "LocalPersistenceProductionLifecyclePlan")
           )

    assert Enum.any?(
             persistence.required_artifacts,
             &String.contains?(&1, "LocalPersistenceOperatorCapturePlan")
           )

    assert Enum.any?(
             persistence.required_artifacts,
             &String.contains?(&1, "LocalPersistenceDefaultDecisionScenarioPlan")
           )

    assert Enum.any?(
             persistence.required_artifacts,
             &String.contains?(&1, "decision_outcome")
           )

    assert Enum.any?(
             persistence.required_artifacts,
             &String.contains?(&1, "persistence negative validation matrix")
           )

    assert Enum.any?(
             persistence.missing_evidence,
             &String.contains?(&1, "LocalPersistenceAcceptance production_default_lifecycle")
           )

    assert Enum.any?(
             persistence.missing_evidence,
             &String.contains?(&1, "Operator/release evidence")
           )

    assert Enum.any?(
             persistence.missing_evidence,
             &String.contains?(&1, "production-default")
           )

    assert Enum.any?(
             persistence.missing_evidence,
             &String.contains?(&1, "LocalPersistenceProductionLifecyclePlan")
           )

    assert Enum.any?(
             persistence.missing_evidence,
             &String.contains?(&1, "persisted beacon refs")
           )

    security = Enum.find(audit.items, &(&1.objective_id == :security_identity))

    assert security.status == :partial

    assert Enum.any?(
             security.required_artifacts,
             &String.contains?(&1, "negative validation matrix")
           )

    assert Enum.any?(
             security.required_artifacts,
             &String.contains?(&1, "decision_outcome keep_unsigned_local_observation")
           )

    assert Enum.any?(
             security.required_artifacts,
             &String.contains?(&1, "LocalSecurityAcceptance")
           )

    assert Enum.any?(
             security.required_artifacts,
             &String.contains?(&1, "LocalSecurityPeerEnrollment")
           )

    assert Enum.any?(
             security.required_artifacts,
             &String.contains?(&1, "LocalSecurityAuthorshipProof")
           )

    assert Enum.any?(
             security.required_artifacts,
             &String.contains?(&1, "LocalSecurityPeerIdentityBinding")
           )

    assert Enum.any?(
             security.required_artifacts,
             &String.contains?(&1, "LocalSecurityReplayProtection")
           )

    assert Enum.any?(
             security.required_artifacts,
             &String.contains?(&1, "LocalSecurityReplayLifecyclePolicy")
           )

    assert Enum.any?(
             security.required_artifacts,
             &String.contains?(&1, "LocalSecurityReplayLifecycleValidation")
           )

    assert Enum.any?(
             security.required_artifacts,
             &String.contains?(&1, "LocalSecurityTrustedMessageDecision")
           )

    assert Enum.any?(
             security.required_artifacts,
             &String.contains?(&1, "LocalSecurityBeaconAuthentication")
           )

    assert Enum.any?(
             security.required_artifacts,
             &String.contains?(&1, "LocalSecurityCanonicalReplayDecision")
           )

    assert Enum.any?(
             security.required_artifacts,
             &String.contains?(&1, "LocalSecurityOperatorTrustPolicy")
           )

    assert Enum.any?(
             security.required_artifacts,
             &String.contains?(&1, "LocalSecurityTrustLifecyclePlan")
           )

    assert Enum.any?(
             security.required_artifacts,
             &String.contains?(&1, "LocalSecurityTrustLifecycleValidation")
           )

    assert Enum.any?(
             security.required_artifacts,
             &String.contains?(&1, "LocalSecurityIdentityValidationPlan")
           )

    assert Enum.any?(
             security.required_artifacts,
             &String.contains?(&1, "LocalSecurityFixtureAudit")
           )

    assert Enum.any?(
             security.required_artifacts,
             &String.contains?(&1, "LocalSecurityReleaseEvidenceReview")
           )

    assert Enum.any?(
             security.required_artifacts,
             &String.contains?(&1, "LocalSecurityDecisionScenarioPlan")
           )

    assert Enum.any?(
             security.required_artifacts,
             &String.contains?(&1, "LocalSecurityOperatorCapturePlan")
           )

    assert Enum.any?(
             security.required_artifacts,
             &String.contains?(&1, "LocalSecurityCryptoNegativeValidation")
           )

    assert Enum.any?(
             security.missing_evidence,
             &String.contains?(&1, "LocalSecurityAcceptance authenticated identity")
           )

    assert Enum.any?(
             security.missing_evidence,
             &String.contains?(&1, "selected security decision_outcome")
           )

    assert Enum.any?(
             security.missing_evidence,
             &String.contains?(&1, "LocalSecurityIdentityValidationPlan")
           )

    assert Enum.any?(
             security.missing_evidence,
             &String.contains?(&1, "LocalSecurityBeaconAuthentication")
           )

    assert Enum.any?(
             security.missing_evidence,
             &String.contains?(&1, "LocalSecurityTrustLifecyclePlan")
           )

    assert Enum.any?(
             security.missing_evidence,
             &String.contains?(&1, "persistent trust lifecycle")
           )

    routing = Enum.find(audit.items, &(&1.objective_id == :routing))

    assert routing.status == :partial

    assert Enum.any?(
             routing.required_artifacts,
             &String.contains?(&1, "decision_outcome keep_advert_only_non_routing")
           )

    assert Enum.any?(
             routing.required_artifacts,
             &String.contains?(&1, "routing negative validation matrix")
           )

    assert Enum.any?(
             routing.required_artifacts,
             &String.contains?(&1, "LocalRoutingAcceptance")
           )

    assert Enum.any?(
             routing.required_artifacts,
             &String.contains?(&1, "LocalRoutingHardwareValidationPlan")
           )

    assert Enum.any?(
             routing.required_artifacts,
             &String.contains?(&1, "LocalRoutingOperatorCapturePlan")
           )

    assert Enum.any?(
             routing.required_artifacts,
             &String.contains?(&1, "LocalRoutingDecisionScenarioPlan")
           )

    assert Enum.any?(
             routing.missing_evidence,
             &String.contains?(&1, "Operator/release evidence")
           )

    assert Enum.any?(
             routing.missing_evidence,
             &String.contains?(&1, "LocalRoutingAcceptance production routing table")
           )

    assert Enum.any?(
             routing.missing_evidence,
             &String.contains?(&1, "stale routes")
           )

    lifecycle = Enum.find(audit.items, &(&1.objective_id == :background_mobile_lifecycle))

    assert lifecycle.status == :partial

    assert Enum.any?(
             lifecycle.required_artifacts,
             &String.contains?(&1, "decision_outcome keep_foreground_manual")
           )

    assert Enum.any?(
             lifecycle.required_artifacts,
             &String.contains?(&1, "lifecycle negative validation matrix")
           )

    assert Enum.any?(
             lifecycle.required_artifacts,
             &String.contains?(&1, "LocalLifecycleAcceptance")
           )

    assert Enum.any?(
             lifecycle.required_artifacts,
             &String.contains?(&1, "LocalLifecycleHardwareValidationPlan")
           )

    assert Enum.any?(
             lifecycle.required_artifacts,
             &String.contains?(&1, "LocalLifecycleOperatorCapturePlan")
           )

    assert Enum.any?(
             lifecycle.required_artifacts,
             &String.contains?(&1, "LocalLifecycleDecisionScenarioPlan")
           )

    assert Enum.any?(
             lifecycle.required_artifacts,
             &String.contains?(&1, "LocalLifecycleEvidenceManifest")
           )

    assert Enum.any?(
             lifecycle.missing_evidence,
             &String.contains?(&1, "Operator/release evidence")
           )

    assert Enum.any?(
             lifecycle.missing_evidence,
             &String.contains?(&1, "LocalLifecycleAcceptance Android foreground service")
           )

    assert Enum.any?(
             lifecycle.missing_evidence,
             &String.contains?(&1, "LocalLifecycleHardwareValidationPlan")
           )

    ios = Enum.find(audit.items, &(&1.objective_id == :ios_parity))

    assert ios.status == :partial

    assert Enum.any?(
             ios.required_artifacts,
             &String.contains?(&1, "iOS parity negative validation matrix")
           )

    assert Enum.any?(
             ios.required_artifacts,
             &String.contains?(&1, "LocalIOSParityAcceptance")
           )

    assert Enum.any?(
             ios.required_artifacts,
             &String.contains?(&1, "LocalIOSParityHardwareValidationPlan")
           )

    assert Enum.any?(
             ios.required_artifacts,
             &String.contains?(&1, "LocalIOSAdvertCarrierDecision")
           )

    assert Enum.any?(
             ios.required_artifacts,
             &String.contains?(&1, "LocalIOSParityOperatorCapturePlan")
           )

    assert Enum.any?(
             ios.required_artifacts,
             &String.contains?(&1, "LocalIOSParityDecisionScenarioPlan")
           )

    assert Enum.any?(
             ios.required_artifacts,
             &String.contains?(&1, "LocalIOSParityEvidenceManifest")
           )

    assert Enum.any?(
             ios.missing_evidence,
             &String.contains?(&1, "LocalIOSParityAcceptance legacy beacon observe")
           )

    assert Enum.any?(
             ios.missing_evidence,
             &String.contains?(&1, "LocalIOSParityHardwareValidationPlan")
           )

    assert Enum.any?(
             ios.missing_evidence,
             &String.contains?(&1, "iOS beacon gossip emit carrier")
           )

    assert Enum.any?(
             ios.missing_evidence,
             &String.contains?(&1, "Android evidence")
           )

    release = Enum.find(audit.items, &(&1.objective_id == :release_hardening))

    assert release.status == :partial

    assert Enum.any?(
             release.required_artifacts,
             &String.contains?(&1, "Release artifact bundle checklist")
           )

    assert Enum.any?(
             release.required_artifacts,
             &String.contains?(&1, "artifact bundle task")
           )

    assert Enum.any?(
             release.required_artifacts,
             &String.contains?(&1, "candidate review task")
           )

    assert Enum.any?(
             release.required_artifacts,
             &String.contains?(&1, "LocalReleaseOperatorCapturePlan")
           )

    assert Enum.any?(
             release.required_artifacts,
             &String.contains?(&1, "LocalReleaseCandidateEvidenceReview")
           )

    assert Enum.any?(
             release.missing_evidence,
             &String.contains?(&1, "Ready LocalReleaseCandidateEvidenceReview")
           )

    assert Enum.any?(
             release.missing_evidence,
             &String.contains?(&1, "local release candidate review task")
           )
  end

  test "checklist distinguishes release, replay, and hardware gates" do
    audit = LocalProjectCompletionAudit.snapshot()

    assert Enum.any?(
             audit.checklist,
             &(&1.id == :completion_gate and &1.status == :blocked)
           )

    assert Enum.any?(
             audit.checklist,
             &(&1.id == :replay_gate and &1.status == :satisfied)
           )

    assert Enum.any?(
             audit.checklist,
             &(&1.id == :hardware_gate and &1.status == :blocked)
           )

    assert "mix test" in audit.required_commands
    assert "mix meshx.mobile.local_completion.audit --allow-open" in audit.required_commands

    assert Enum.any?(
             audit.required_commands,
             &String.contains?(&1, "local-completion-audit.txt")
           )
  end

  test "top-level required commands cover every completion evidence surface" do
    audit = LocalProjectCompletionAudit.snapshot()

    required_command_fragments = [
      "advert_gossip.audit",
      "local-completion-audit.txt",
      "local_completion.blocker_matrix",
      "local_full_resolution.evidence",
      "local_full_resolution.transport_review",
      "local_full_resolution.transport_review --template",
      "local_known_good_transport.review",
      "local_known_good_transport.review --template",
      "local_inbox.ux_evidence",
      "local_inbox.ux_review",
      "local_inbox.ux_review --template",
      "local_persistence.evidence",
      "local_persistence.production_review",
      "local_persistence.production_review --template",
      "local_security.evidence",
      "local_security.release_review",
      "local_security.release_review --template",
      "local_routing.evidence",
      "local_routing.production_review",
      "local_routing.production_review --template",
      "local_lifecycle.validation_plan",
      "local_lifecycle.evidence",
      "local_lifecycle.hardware_review",
      "local_lifecycle.hardware_review --template",
      "local_ios_parity.evidence",
      "local_ios_parity.hardware_review",
      "local_ios_parity.hardware_review --template",
      "local_multi_hop_hardware.evidence",
      "local_multi_hop_hardware.review",
      "local_multi_hop_hardware.review --template",
      "local_release.artifact_bundle",
      "local_release.candidate_review",
      "local_release.candidate_review --template",
      "local_release.manifest",
      "local_release.recent_evidence",
      "local_readiness.audit"
    ]

    for fragment <- required_command_fragments do
      assert Enum.any?(audit.required_commands, &String.contains?(&1, fragment))
    end
  end

  test "prompt checklist verification commands are listed as top-level required commands" do
    audit = LocalProjectCompletionAudit.snapshot()
    required_commands = MapSet.new(audit.required_commands)

    missing_commands =
      audit.prompt_artifact_checklist
      |> Enum.flat_map(& &1.verification_commands)
      |> Enum.uniq()
      |> Enum.reject(&MapSet.member?(required_commands, &1))
      |> Enum.sort()

    assert missing_commands == []
  end

  test "prompt checklist objective IDs stay partitioned by blocker matrix" do
    audit = LocalProjectCompletionAudit.snapshot()

    checklist_ids =
      audit.prompt_artifact_checklist
      |> Enum.map(& &1.objective_id)
      |> MapSet.new()

    matrix_ids =
      (audit.blocker_matrix.blocked_by_new_hardware ++
         audit.blocker_matrix.can_progress_without_new_hardware)
      |> MapSet.new()

    assert MapSet.disjoint?(
             MapSet.new(audit.blocker_matrix.blocked_by_new_hardware),
             MapSet.new(audit.blocker_matrix.can_progress_without_new_hardware)
           )

    assert MapSet.equal?(checklist_ids, matrix_ids)
  end

  test "prompt checklist statuses match blocker matrix entries" do
    audit = LocalProjectCompletionAudit.snapshot()

    matrix_statuses =
      audit.blocker_matrix.entries
      |> Map.new(&{&1.objective_id, &1.status})

    for checklist_item <- audit.prompt_artifact_checklist do
      assert checklist_item.status == Map.fetch!(matrix_statuses, checklist_item.objective_id)
    end
  end

  test "recommended next action points at a no-new-hardware prompt checklist objective" do
    audit = LocalProjectCompletionAudit.snapshot()
    recommended = audit.blocker_matrix.next_action_summary.recommended_now

    prompt_ids =
      audit.prompt_artifact_checklist
      |> Enum.map(& &1.objective_id)
      |> MapSet.new()

    no_new_hardware_ids =
      audit.blocker_matrix.next_action_summary.can_progress_without_new_hardware
      |> Enum.map(& &1.objective_id)
      |> MapSet.new()

    assert recommended.objective_id in audit.blocker_matrix.can_progress_without_new_hardware
    assert MapSet.member?(prompt_ids, recommended.objective_id)
    assert MapSet.member?(no_new_hardware_ids, recommended.objective_id)
    assert recommended.next_unblock_action != ""
    assert recommended.required_evidence != []
  end

  test "review template coverage requires every operator review to expose a scaffold command" do
    coverage = LocalProjectCompletionAudit.snapshot().review_template_coverage

    assert coverage.boundary == :operator_review_template_coverage
    assert coverage.all_review_templates_listed?
    assert coverage.covered_review_count == coverage.review_count
    assert coverage.review_count == 10

    expected_review_ids = [
      :full_resolution_transport,
      :nearby_messages_ux,
      :ios_parity_hardware,
      :known_good_transport,
      :mobile_lifecycle_hardware,
      :multi_hop_hardware,
      :production_persistence,
      :release_candidate,
      :production_routing,
      :security_release
    ]

    assert Enum.map(coverage.entries, & &1.review_id) == expected_review_ids

    for entry <- coverage.entries do
      assert entry.status == :covered
      assert entry.template_command_listed?
      assert entry.review_command_listed?
      assert String.contains?(entry.template_command, " --template ")
      assert String.contains?(entry.review_command, " --input ")
    end
  end

  test "prompt artifact checklist maps every requested objective to evidence and gaps" do
    audit = LocalProjectCompletionAudit.snapshot()

    assert length(audit.deliverables) == 10
    assert length(audit.prompt_artifact_checklist) == 10

    assert Enum.map(audit.prompt_artifact_checklist, & &1.number) == Enum.to_list(1..10)

    item_ids = Enum.map(audit.items, & &1.objective_id)
    checklist_ids = Enum.map(audit.prompt_artifact_checklist, & &1.objective_id)

    assert checklist_ids == item_ids

    for checklist_item <- audit.prompt_artifact_checklist do
      audit_item = Enum.find(audit.items, &(&1.objective_id == checklist_item.objective_id))

      assert checklist_item.status == audit_item.status
      refute checklist_item.completion_claim_allowed?
      assert is_binary(checklist_item.prompt_requirement)
      assert checklist_item.prompt_requirement != ""
      assert checklist_item.current_evidence != []
      assert checklist_item.required_artifacts != []
      assert checklist_item.missing_evidence != []
      assert checklist_item.verification_commands != []
    end

    full_resolution =
      Enum.find(audit.prompt_artifact_checklist, &(&1.objective_id == :full_message_resolution))

    assert full_resolution.status == :blocked
    refute full_resolution.completion_claim_allowed?
    assert full_resolution.prompt_requirement =~ "Beacon refs"
    assert full_resolution.prompt_requirement =~ "fake/offline fetch work exist"
    assert full_resolution.prompt_requirement =~ "real fetch transport"
    assert full_resolution.prompt_requirement =~ "replay-parse a full MessageEnvelope"
    assert "BeaconRef" in full_resolution.required_artifacts
    assert "LocalFetchTransportValidationPlan" in full_resolution.required_artifacts
    assert "LocalFullMessageResolutionEvidenceManifest" in full_resolution.required_artifacts
    assert "LocalKnownGoodTransportEvidenceReview" in full_resolution.required_artifacts

    assert Enum.any?(
             full_resolution.verification_commands,
             &String.contains?(&1, "local_full_resolution.evidence")
           )

    assert Enum.any?(
             full_resolution.verification_commands,
             &String.contains?(&1, "local_known_good_transport.review")
           )

    assert Enum.any?(
             full_resolution.verification_commands,
             &String.contains?(&1, "local_readiness")
           )

    known_good =
      Enum.find(
        audit.prompt_artifact_checklist,
        &(&1.objective_id == :known_good_transport_validation)
      )

    assert known_good.status == :blocked
    assert known_good.prompt_requirement =~ "SM-T577U/SM-T390"
    assert known_good.prompt_requirement =~ "status 133"
    assert known_good.prompt_requirement =~ "standalone GATT"
    assert known_good.prompt_requirement =~ "another constrained fetch transport"
    assert "LocalKnownGoodTransportEvidenceReview" in known_good.required_artifacts

    assert Enum.any?(
             known_good.verification_commands,
             &String.contains?(&1, "local_known_good_transport.review --template")
           )

    multi_hop =
      Enum.find(audit.prompt_artifact_checklist, &(&1.objective_id == :multi_hop_hardware_proof))

    assert multi_hop.status == :blocked
    assert multi_hop.prompt_requirement =~ "Replay proves protocol behavior"
    assert multi_hop.prompt_requirement =~ "one-hop legacy beacon gossip has hardware scope"
    assert multi_hop.prompt_requirement =~ "physical multi-hop beacon gossip"
    assert multi_hop.prompt_requirement =~ "origin, relay, and observer roles"
    assert multi_hop.prompt_requirement =~ "three devices"
    assert "LocalAdvertGossipHardwareValidationPlan" in multi_hop.required_artifacts
    assert "LocalMultiHopHardwareEvidenceManifest" in multi_hop.required_artifacts

    assert Enum.any?(
             multi_hop.verification_commands,
             &String.contains?(&1, "local_multi_hop_hardware.evidence")
           )

    product_ux =
      Enum.find(audit.prompt_artifact_checklist, &(&1.objective_id == :product_ux))

    assert product_ux.status == :partial
    assert product_ux.prompt_requirement =~ "native surface controls"
    assert product_ux.prompt_requirement =~ "filters"
    assert product_ux.prompt_requirement =~ "sorting"
    assert product_ux.prompt_requirement =~ "detail evidence exist"
    assert product_ux.prompt_requirement =~ "target-device evidence"
    assert product_ux.prompt_requirement =~ "copy anchors"
    assert product_ux.prompt_requirement =~ "visual density"
    assert "LocalInboxUxValidationPlan" in product_ux.required_artifacts

    assert Enum.any?(
             product_ux.required_artifacts,
             &String.contains?(&1, "LocalInboxUxOperatorCapturePlan")
           )

    assert Enum.any?(
             product_ux.required_artifacts,
             &String.contains?(&1, "LocalInboxUxTargetDeviceScenarioPlan")
           )

    assert Enum.any?(
             product_ux.required_artifacts,
             &String.contains?(&1, "LocalInboxUxDecisionScenarioPlan")
           )

    assert Enum.any?(product_ux.missing_evidence, &String.contains?(&1, "evidence_kind"))

    assert Enum.any?(
             product_ux.verification_commands,
             &String.contains?(&1, "local_inbox.ux_validation_plan")
           )

    assert Enum.any?(
             product_ux.verification_commands,
             &String.contains?(&1, "local_inbox.ux_review --template")
           )

    persistence =
      Enum.find(audit.prompt_artifact_checklist, &(&1.objective_id == :persistence))

    assert persistence.status == :partial
    assert String.contains?(persistence.prompt_requirement, "memory-only by default")
    assert String.contains?(persistence.prompt_requirement, "opt-in durable snapshots")
    assert String.contains?(persistence.prompt_requirement, "production-default message/ref persistence")
    assert "LocalPersistenceProductionLifecyclePlan" in persistence.required_artifacts

    assert Enum.any?(
             persistence.required_artifacts,
             &String.contains?(&1, "LocalPersistenceOperatorCapturePlan")
           )

    assert Enum.any?(
             persistence.required_artifacts,
             &String.contains?(&1, "LocalPersistenceDefaultDecisionScenarioPlan")
           )

    assert Enum.any?(
             persistence.verification_commands,
             &String.contains?(&1, "local_persistence.lifecycle_plan")
           )

    assert Enum.any?(
             persistence.verification_commands,
             &String.contains?(&1, "local_persistence.production_review --template")
           )

    security =
      Enum.find(audit.prompt_artifact_checklist, &(&1.objective_id == :security_identity))

    assert security.status == :partial
    assert String.contains?(security.prompt_requirement, "Pure authorship")
    assert String.contains?(security.prompt_requirement, "peer-binding")
    assert String.contains?(security.prompt_requirement, "current BLE refs remain unsigned hash references")
    assert String.contains?(security.prompt_requirement, "beacon authentication")
    assert String.contains?(security.prompt_requirement, "trust lifecycle evidence")
    assert "LocalSecurityDecisionScenarioPlan" in security.required_artifacts
    assert "LocalSecurityOperatorCapturePlan" in security.required_artifacts
    assert "LocalSecurityReleaseEvidenceReview" in security.required_artifacts

    assert Enum.any?(
             security.verification_commands,
             &String.contains?(&1, "local_security.validation_plan")
           )

    assert Enum.any?(
             security.verification_commands,
             &String.contains?(&1, "local_security.release_review --template")
           )

    routing = Enum.find(audit.prompt_artifact_checklist, &(&1.objective_id == :routing))

    assert routing.status == :partial
    assert String.contains?(routing.prompt_requirement, "Replay gossip")
    assert String.contains?(routing.prompt_requirement, "route candidates")
    assert String.contains?(routing.prompt_requirement, "keep-advert-only non-routing policy")
    assert String.contains?(routing.prompt_requirement, "production routing")
    assert "LocalRoutingProductionEvidenceReview" in routing.required_artifacts

    assert Enum.any?(
             routing.required_artifacts,
             &String.contains?(&1, "LocalRoutingOperatorCapturePlan")
           )

    assert Enum.any?(
             routing.required_artifacts,
             &String.contains?(&1, "LocalRoutingDecisionScenarioPlan")
           )

    assert Enum.any?(
             routing.verification_commands,
             &String.contains?(&1, "local_routing.validation_plan")
           )

    assert Enum.any?(
             routing.verification_commands,
             &String.contains?(&1, "local_routing.production_review --template")
           )

    lifecycle =
      Enum.find(
        audit.prompt_artifact_checklist,
        &(&1.objective_id == :background_mobile_lifecycle)
      )

    assert lifecycle.status == :partial
    assert String.contains?(lifecycle.prompt_requirement, "Foreground/manual lifecycle policy")
    assert String.contains?(lifecycle.prompt_requirement, "Android foreground service")
    assert String.contains?(lifecycle.prompt_requirement, "iOS background behavior")
    assert String.contains?(lifecycle.prompt_requirement, "background gossip")
    assert "LocalLifecycleEvidenceManifest" in lifecycle.required_artifacts

    assert Enum.any?(
             lifecycle.required_artifacts,
             &String.contains?(&1, "LocalLifecycleOperatorCapturePlan")
           )

    assert Enum.any?(
             lifecycle.required_artifacts,
             &String.contains?(&1, "LocalLifecycleDecisionScenarioPlan")
           )

    assert Enum.any?(
             lifecycle.verification_commands,
             &String.contains?(&1, "local_lifecycle.validation_plan")
           )

    assert Enum.any?(
             lifecycle.verification_commands,
             &String.contains?(&1, "local_lifecycle.evidence")
           )

    ios = Enum.find(audit.prompt_artifact_checklist, &(&1.objective_id == :ios_parity))

    assert ios.status == :partial
    assert String.contains?(ios.prompt_requirement, "iOS contract")
    assert String.contains?(ios.prompt_requirement, "foreground observe source evidence")
    assert String.contains?(ios.prompt_requirement, "Android legacy beacon gossip proof")
    assert String.contains?(ios.prompt_requirement, "iOS hardware parity")
    assert "LocalIOSParityOperatorCapturePlan" in ios.required_artifacts
    assert "LocalIOSParityDecisionScenarioPlan" in ios.required_artifacts
    assert "LocalIOSParityEvidenceManifest" in ios.required_artifacts

    assert Enum.any?(
             ios.verification_commands,
             &String.contains?(&1, "local_ios_parity.evidence")
           )

    release =
      Enum.find(audit.prompt_artifact_checklist, &(&1.objective_id == :release_hardening))

    assert release.status == :partial
    assert "LocalReleaseOperatorCapturePlan" in release.required_artifacts
    assert "LocalReleaseCandidateEvidenceReview" in release.required_artifacts
    assert "LocalReleaseRecentEvidenceInventory" in release.required_artifacts

    assert Enum.any?(
             release.verification_commands,
             &String.contains?(&1, "local_release.artifact_bundle")
           )

    assert Enum.any?(
             release.verification_commands,
             &String.contains?(&1, "local_release.candidate_review")
           )

    assert Enum.any?(
             release.verification_commands,
             &String.contains?(&1, "local_release.manifest")
           )

    assert Enum.any?(
             release.verification_commands,
             &String.contains?(&1, "local_release.recent_evidence")
           )
  end

  test "json snapshot is machine readable and preserves false completion" do
    audit = LocalProjectCompletionAudit.json_snapshot()

    assert audit["audit_version"] == 1
    assert audit["whole_project_complete?"] == false
    assert audit["completion_claim_allowed?"] == false
    assert audit["open_item_count"] == 10
    assert length(audit["prompt_artifact_checklist"]) == 10

    assert Enum.any?(
             audit["items"],
             &(&1["objective_id"] == "ios_parity" and &1["status"] == "partial")
           )
  end
end
