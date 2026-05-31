defmodule Mob.Node.BLE.LocalInboxUxOperatorCapturePlanTest do
  use ExUnit.Case, async: true

  alias Mob.Node.BLE.LocalInboxUxOperatorCapturePlan

  test "snapshot exposes the target-device capture checklist without production claims" do
    plan = LocalInboxUxOperatorCapturePlan.snapshot()

    assert plan.boundary == :nearby_messages_operator_capture_plan
    assert plan.status == :open
    refute plan.production_ux_claim_allowed?
    refute plan.delivery_claim_allowed?
    refute plan.trusted_delivery_claim_allowed?
    refute plan.routing_claim_allowed?
    assert plan.allowed_evidence_kinds == [:screenshot, :operator_note]
    assert plan.artifact_root == "artifacts/local-ble/<run-id>/ux/"
  end

  test "capture sections cover review sections and validation gates" do
    plan = LocalInboxUxOperatorCapturePlan.snapshot()

    section_ids = Enum.map(plan.capture_sections, & &1.id)

    assert [
             :target_devices,
             :state_evidence,
             :interaction_evidence,
             :selected_detail_evidence,
             :copy_review,
             :visual_density_review
           ] -- section_ids == []

    assert plan.expected_review_sections -- section_ids == []

    gate_ids =
      plan.capture_sections
      |> Enum.flat_map(& &1.gate_ids)
      |> Enum.uniq()

    assert [
             :target_device_matrix,
             :state_coverage_screenshots,
             :interaction_coverage,
             :blocked_claim_copy_review,
             :visual_density_review
           ] -- gate_ids == []
  end

  test "state and selected-detail capture entries cover every Nearby Messages state" do
    plan = LocalInboxUxOperatorCapturePlan.snapshot()
    state_section = Enum.find(plan.capture_sections, &(&1.id == :state_evidence))
    detail_section = Enum.find(plan.capture_sections, &(&1.id == :selected_detail_evidence))

    assert [:full_message, :unresolved_ref, :gossiped_ref, :stale_ref] --
             Enum.map(state_section.required_entries, & &1.state) == []

    assert [:full_message, :unresolved_ref, :gossiped_ref, :stale_ref] --
             Enum.map(detail_section.required_entries, & &1.state) == []

    assert Enum.all?(detail_section.required_entries, fn entry ->
             String.contains?(entry.required_copy, "blocked claims")
           end)
  end

  test "copy and density review preserve blocked claim wording requirements" do
    plan = LocalInboxUxOperatorCapturePlan.snapshot()
    copy = Enum.find(plan.capture_sections, &(&1.id == :copy_review))
    density = Enum.find(plan.capture_sections, &(&1.id == :visual_density_review))

    assert copy.required_blocked_claims == [
             :delivery,
             :trusted_delivery,
             :routing,
             :background_operation
           ]

    assert :blocked_claims_called_out in copy.required_entries
    assert :control_summaries_captured in copy.required_entries
    assert :detail_panel_copy_captured in copy.required_entries
    assert :densest_fixture_captured in density.required_entries
    assert :densest_fixture_artifact_path in density.required_entries
    assert :densest_fixture_evidence_kind in density.required_entries
    assert :detail_readability_reviewed in density.required_entries

    assert density.densest_fixture_artifact_path ==
             "artifacts/local-ble/<run-id>/ux/visual-density-densest.png"

    assert density.densest_fixture_evidence_kind == :screenshot
  end

  test "JSON snapshot is archiveable" do
    plan = LocalInboxUxOperatorCapturePlan.json_snapshot()

    assert plan["boundary"] == "nearby_messages_operator_capture_plan"
    assert plan["status"] == "open"
    assert length(plan["capture_sections"]) == 6
    assert plan["production_ux_claim_allowed?"] == false
  end
end
