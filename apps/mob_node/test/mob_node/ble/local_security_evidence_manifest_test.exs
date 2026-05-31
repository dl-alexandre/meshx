defmodule Mob.Node.BLE.LocalSecurityEvidenceManifestTest do
  use ExUnit.Case, async: true

  alias Mob.Node.BLE.LocalSecurityEvidenceManifest

  test "snapshot packages local security evidence while keeping claims blocked" do
    manifest = LocalSecurityEvidenceManifest.snapshot()

    assert manifest.boundary == :local_security_evidence_manifest
    refute manifest.security_evidence_complete?
    refute manifest.authenticated_peer_identity_claim_allowed?
    refute manifest.authenticated_message_claim_allowed?
    refute manifest.trusted_message_claim_allowed?
    refute manifest.trusted_delivery_claim_allowed?

    assert manifest.current_security_decision.decision_outcome ==
             :keep_unsigned_local_observation

    assert manifest.current_security_decision.decision_status ==
             :selected_for_current_validated_mode

    assert manifest.security_decision_scenario_plan.boundary ==
             :local_security_decision_scenario_plan

    assert manifest.security_scope.current_mode == :unsigned_local_ble_observations
    assert manifest.security_scope.scope_status == :partial_security_boundary
    assert :canonical_replay_ingress in manifest.security_scope.implemented_boundaries

    assert :crypto_negative_validation_fixture_inventory in manifest.security_scope.implemented_boundaries

    assert :message_authorship_proof in manifest.security_scope.requires_before_trusted_message

    assert :full_envelope_resolution_for_beacon_refs in manifest.security_scope.requires_before_trusted_message

    assert :beacon_ref_authorship in manifest.security_scope.not_evidence_of
    assert :authenticated_ble_hardware in manifest.security_scope.not_evidence_of

    assert length(manifest.security_decision_scenario_plan.decision_scenarios) == 2
    refute manifest.current_security_decision.authenticated_peer_identity_enabled?
    refute manifest.current_security_decision.authenticated_message_enabled?
    refute manifest.current_security_decision.trusted_message_claim_allowed?
    refute manifest.current_security_decision.trusted_delivery_claim_allowed?
    assert manifest.open_security_gate_count == 8
    assert manifest.partial_fixture_group_count >= 1
    assert manifest.blocked_fixture_group_count >= 1
    assert :trusted_delivery in manifest.blocked_claims
  end

  test "manifest embeds validation, lifecycle, fixture, and release review evidence" do
    manifest = LocalSecurityEvidenceManifest.snapshot()

    assert manifest.validation_plan.boundary == :authenticated_local_ble_security_validation_plan
    assert manifest.fixture_audit.boundary == :local_security_fixture_inventory
    assert manifest.acceptance.boundary == :current_unsigned_local_ble_security
    assert manifest.replay_lifecycle_policy.boundary == :memory_only_replay_lifecycle_policy
    assert manifest.replay_lifecycle_validation.all_cases_passed?
    assert manifest.trust_lifecycle_validation.all_cases_passed?
    assert manifest.beacon_reference_risk.boundary == :hash_only_beacon_reference_security_risk
    refute manifest.beacon_reference_risk.authenticated_message_claim_allowed?
    assert manifest.operator_capture_plan.boundary == :local_security_operator_capture_plan
    assert length(manifest.operator_capture_plan.capture_sections) == 8
    refute manifest.operator_capture_plan.trusted_delivery_claim_allowed?
    assert manifest.release_evidence_review.boundary == :local_security_release_evidence_review
  end

  test "manifest lists the validation plan artifact before release review" do
    manifest = LocalSecurityEvidenceManifest.snapshot()

    assert Enum.any?(
             manifest.required_commands,
             &String.contains?(&1, "local_security.validation_plan")
           )

    assert Enum.any?(
             manifest.required_artifacts,
             &(&1.id == :security_validation_plan)
           )

    assert Enum.any?(
             manifest.required_artifacts,
             &(&1.id == :current_security_decision)
           )

    assert Enum.any?(
             manifest.required_artifacts,
             &(&1.id == :security_decision_scenario_plan)
           )
  end

  test "release review is present but remains open until operator review is attached" do
    manifest = LocalSecurityEvidenceManifest.snapshot()

    assert manifest.release_evidence_review.status == :open
    refute manifest.release_evidence_review.security_release_evidence_complete?
    assert "Security attachments must be operator reviewed." in manifest.missing_release_evidence

    assert Enum.any?(
             manifest.required_commands,
             &String.contains?(&1, "local_security.release_review")
           )

    assert Enum.any?(
             manifest.required_commands,
             &String.contains?(&1, "local_security.release_review --template")
           )

    assert Enum.any?(
             manifest.required_artifacts,
             &(&1.id == :security_release_review)
           )

    assert Enum.any?(
             manifest.required_artifacts,
             &(&1.id == :security_release_review_template)
           )

    assert Enum.any?(
             manifest.required_artifacts,
             &(&1.id == :security_operator_capture_plan)
           )
  end

  test "required commands include authorship replay trust and fixture audit security gates" do
    manifest = LocalSecurityEvidenceManifest.snapshot()

    assert Enum.any?(
             manifest.required_commands,
             &String.contains?(&1, "local_security_authorship_proof_test.exs")
           )

    assert Enum.any?(
             manifest.required_commands,
             &String.contains?(&1, "local_security_canonical_replay_decision_test.exs")
           )

    assert Enum.any?(
             manifest.required_commands,
             &String.contains?(&1, "local_security_decision_scenario_plan_test.exs")
           )

    assert Enum.any?(
             manifest.required_commands,
             &String.contains?(&1, "local_security_fixture_audit_test.exs")
           )

    assert Enum.any?(
             manifest.required_commands,
             &String.contains?(&1, "local_security_operator_capture_plan_test.exs")
           )

    assert Enum.any?(
             manifest.required_commands,
             &String.contains?(&1, "local_security_beacon_reference_risk_test.exs")
           )

    assert Enum.any?(
             manifest.required_commands,
             &String.contains?(&1, "local_security_replay_lifecycle_validation_test.exs")
           )

    assert Enum.any?(
             manifest.required_commands,
             &String.contains?(&1, "local_security_trust_lifecycle_validation_test.exs")
           )
  end

  test "JSON snapshot preserves blocked trusted claims" do
    manifest = LocalSecurityEvidenceManifest.json_snapshot()

    assert manifest["boundary"] == "local_security_evidence_manifest"
    assert manifest["security_evidence_complete?"] == false
    assert manifest["security_scope"]["current_mode"] == "unsigned_local_ble_observations"
    assert manifest["security_scope"]["scope_status"] == "partial_security_boundary"

    assert "message_authorship_proof" in manifest["security_scope"][
             "requires_before_trusted_message"
           ]

    assert "beacon_ref_authorship" in manifest["security_scope"]["not_evidence_of"]

    assert manifest["current_security_decision"]["decision_outcome"] ==
             "keep_unsigned_local_observation"

    assert manifest["trusted_message_claim_allowed?"] == false
    assert manifest["trusted_delivery_claim_allowed?"] == false

    assert manifest["security_decision_scenario_plan"]["boundary"] ==
             "local_security_decision_scenario_plan"

    assert length(manifest["security_decision_scenario_plan"]["decision_scenarios"]) == 2
    assert manifest["operator_capture_plan"]["boundary"] == "local_security_operator_capture_plan"
    assert length(manifest["operator_capture_plan"]["capture_sections"]) == 8
    assert "trusted_delivery" in manifest["blocked_claims"]
  end
end
