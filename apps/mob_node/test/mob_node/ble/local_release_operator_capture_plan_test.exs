defmodule Mob.Node.BLE.LocalReleaseOperatorCapturePlanTest do
  use ExUnit.Case, async: true

  alias Mob.Node.BLE.{
    LocalReleaseCandidateEvidenceReview,
    LocalReleaseEvidenceManifest,
    LocalReleaseOperatorCapturePlan
  }

  test "snapshot exposes release capture plan without enabling release claims" do
    plan = LocalReleaseOperatorCapturePlan.snapshot()

    assert plan.boundary == :local_release_operator_capture_plan
    assert plan.status == :open
    assert plan.mode == :advertisement_only_local_mesh
    refute plan.release_candidate_complete?
    refute plan.release_candidate_evidence_complete?
    refute plan.whole_project_complete?
    refute plan.release_candidate_claim_allowed?
    refute plan.delivery_claim_allowed?
    refute plan.trusted_delivery_claim_allowed?
    refute plan.routed_delivery_claim_allowed?
    refute plan.background_operation_claim_allowed?
    refute plan.ios_parity_claim_allowed?
  end

  test "capture sections cover release manifests reviews hardware notes and final review" do
    plan = LocalReleaseOperatorCapturePlan.snapshot()
    section_ids = Enum.map(plan.capture_sections, & &1.id)

    assert [
             :manifest_paths,
             :objective_review_paths,
             :hardware_attachments,
             :operator_release_notes,
             :candidate_review
           ] -- section_ids == []

    assert length(plan.capture_sections) == 5
  end

  test "sections preserve release review requirements and blocked claims" do
    plan = LocalReleaseOperatorCapturePlan.snapshot()

    for section <- plan.capture_sections do
      assert section.artifact_path =~ "artifacts/local-ble/<run-id>/release-candidate/"
      assert section.evidence_type
      assert section.required_entries != []
      assert plan.required_blocked_claims -- section.blocked_claims_called_out == []
    end

    hardware = Enum.find(plan.capture_sections, &(&1.id == :hardware_attachments))
    manifests = Enum.find(plan.capture_sections, &(&1.id == :manifest_paths))
    notes = Enum.find(plan.capture_sections, &(&1.id == :operator_release_notes))

    assert :completion_audit_path in manifests.required_entries
    assert :completion_audit_plain_text_path in manifests.required_entries
    assert :focused_remaining_items_audit_path in manifests.required_entries
    assert :focused_remaining_items_plain_text_path in manifests.required_entries
    assert :direct_full_mx_aux_validation_checklist_path in manifests.required_entries
    assert :upstream_patch_maintainer_handoff_path in manifests.required_entries
    assert :recent_evidence_inventory_path in manifests.required_entries
    assert Enum.any?(manifests.notes, &String.contains?(&1, "JSON completion audit"))
    assert Enum.any?(manifests.notes, &String.contains?(&1, "plain-text completion audit"))
    assert Enum.any?(manifests.notes, &String.contains?(&1, "focused remaining-items audit"))
    assert Enum.any?(manifests.notes, &String.contains?(&1, "AUX validation checklist"))
    assert Enum.any?(manifests.notes, &String.contains?(&1, "upstream maintainer handoff"))
    assert Enum.any?(manifests.notes, &String.contains?(&1, "recent-evidence inventory"))
    assert :evidence_types_by_gate in hardware.required_entries
    assert :allowed_wording in notes.required_entries
    assert plan.allowed_wording == LocalReleaseCandidateEvidenceReview.allowed_wording()
  end

  test "open hardware gates and evidence types align with release review inputs" do
    plan = LocalReleaseOperatorCapturePlan.snapshot()

    expected_open_gates =
      LocalReleaseEvidenceManifest.open_entries()
      |> Enum.map(& &1.gate_id)

    assert plan.open_hardware_gate_ids == expected_open_gates
    assert plan.open_hardware_gate_count == length(expected_open_gates)

    assert plan.required_gate_evidence_types ==
             LocalReleaseCandidateEvidenceReview.required_gate_evidence_types()
  end

  test "JSON snapshot is archiveable" do
    plan = LocalReleaseOperatorCapturePlan.json_snapshot()

    assert plan["boundary"] == "local_release_operator_capture_plan"
    assert plan["status"] == "open"
    assert length(plan["capture_sections"]) == 5
    assert plan["release_candidate_complete?"] == false
    assert plan["whole_project_complete?"] == false

    manifests =
      Enum.find(plan["capture_sections"], &(&1["id"] == "manifest_paths"))

    assert "focused_remaining_items_audit_path" in manifests["required_entries"]
    assert "direct_full_mx_aux_validation_checklist_path" in manifests["required_entries"]
    assert "upstream_patch_maintainer_handoff_path" in manifests["required_entries"]
    assert "recent_evidence_inventory_path" in manifests["required_entries"]
  end
end
