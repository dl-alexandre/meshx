defmodule MeshxMobileApp.BLE.LocalSecurityOperatorCapturePlanTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.{
    LocalSecurityOperatorCapturePlan,
    LocalSecurityReleaseEvidenceReview
  }

  test "snapshot exposes security capture plan without enabling trusted claims" do
    plan = LocalSecurityOperatorCapturePlan.snapshot()

    assert plan.boundary == :local_security_operator_capture_plan
    assert plan.status == :open
    assert plan.current_mode == :unsigned_local_ble_observations
    assert plan.current_security_decision.decision_outcome == :keep_unsigned_local_observation
    refute plan.security_release_evidence_complete?
    refute plan.authenticated_peer_identity_claim_allowed?
    refute plan.authenticated_message_claim_allowed?
    refute plan.trusted_message_claim_allowed?
    refute plan.trusted_delivery_claim_allowed?
    refute plan.fresh_message_claim_allowed?
  end

  test "capture sections cover every security release review gate" do
    plan = LocalSecurityOperatorCapturePlan.snapshot()
    section_ids = Enum.map(plan.capture_sections, & &1.id)

    assert plan.required_plan_gate_ids ==
             LocalSecurityReleaseEvidenceReview.required_plan_gate_ids()

    assert plan.required_plan_gate_ids -- section_ids == []
    assert length(plan.capture_sections) == 8
  end

  test "each section has review attachment fields evidence type and blocked claims" do
    plan = LocalSecurityOperatorCapturePlan.snapshot()

    for section <- plan.capture_sections do
      assert section.review_section == :security_attachments
      assert section.artifact_path =~ "artifacts/local-ble/<run-id>/security/"
      assert :artifact_id in section.required_entries
      assert :path in section.required_entries
      assert :source in section.required_entries
      assert :plan_gate_ids in section.required_entries
      assert :evidence_types_by_gate in section.required_entries
      assert :blocked_claims_called_out in section.required_entries
      assert :operator_reviewed? in section.required_entries
      assert section.evidence_type == Map.fetch!(plan.required_evidence_types, section.id)
      assert plan.required_blocked_claims -- section.blocked_claims_called_out == []
      assert section.gate_specific_blocked_claims_called_out != []
    end
  end

  test "beacon authentication and negative sections preserve security boundaries" do
    plan = LocalSecurityOperatorCapturePlan.snapshot()

    beacon =
      Enum.find(plan.capture_sections, &(&1.id == :beacon_ref_authentication_integration))

    negative = Enum.find(plan.capture_sections, &(&1.id == :negative_claim_review))

    assert beacon.evidence_type == :beacon_authentication_fixture
    assert negative.evidence_type == :crypto_negative_fixture_matrix
    assert Enum.any?(beacon.notes, &String.contains?(&1, "resolved trusted full envelope"))
    assert Enum.any?(negative.notes, &String.contains?(&1, "hash-only beacon promotion"))
  end

  test "JSON snapshot is archiveable" do
    plan = LocalSecurityOperatorCapturePlan.json_snapshot()

    assert plan["boundary"] == "local_security_operator_capture_plan"
    assert plan["status"] == "open"
    assert length(plan["capture_sections"]) == 8
    assert plan["trusted_delivery_claim_allowed?"] == false
  end
end
