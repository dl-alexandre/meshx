defmodule Mob.Node.BLE.LocalInboxUxTargetDeviceScenarioPlanTest do
  use ExUnit.Case, async: true

  alias Mob.Node.BLE.LocalInboxUxTargetDeviceScenarioPlan

  test "snapshot exposes target-device UX scenarios without production claims" do
    plan = LocalInboxUxTargetDeviceScenarioPlan.snapshot()

    assert plan.boundary == :nearby_messages_target_device_scenario_plan
    assert plan.status == :open
    refute plan.production_ux_claim_allowed?
    refute plan.delivery_claim_allowed?
    refute plan.trusted_delivery_claim_allowed?
    refute plan.routing_claim_allowed?
    assert plan.allowed_evidence_kinds == [:screenshot, :operator_note]
    assert plan.artifact_root == "artifacts/local-ble/<run-id>/ux/"
  end

  test "state row scenarios cover every Nearby Messages state" do
    plan = LocalInboxUxTargetDeviceScenarioPlan.snapshot()
    states = Enum.map(plan.state_row_scenarios, & &1.state)

    assert [:full_message, :unresolved_ref, :gossiped_ref, :stale_ref] -- states == []

    assert Enum.all?(plan.state_row_scenarios, fn scenario ->
             scenario.review_section == :state_evidence and
               scenario.allowed_evidence_kinds == [:screenshot, :operator_note] and
               scenario.required_visible_copy != [] and
               scenario.blocked_claims_called_out != [] and
               scenario.delivery_claim_allowed? == false
           end)
  end

  test "filter sort and detail scenarios cover expected controls" do
    plan = LocalInboxUxTargetDeviceScenarioPlan.snapshot()

    assert [:all, :full_message, :unresolved_ref, :gossiped_ref, :stale_ref] --
             Enum.map(plan.filter_scenarios, & &1.selected_state) == []

    assert [
             :recent_first,
             :state_then_recent,
             :strongest_rssi,
             :payload_kind_then_recent,
             :oldest_first
           ] --
             Enum.map(plan.sort_scenarios, & &1.sort) == []

    assert [:full_message, :unresolved_ref, :gossiped_ref, :stale_ref] --
             Enum.map(plan.selected_detail_scenarios, & &1.state) == []

    full = Enum.find(plan.selected_detail_scenarios, &(&1.state == :full_message))
    ref = Enum.find(plan.selected_detail_scenarios, &(&1.state == :unresolved_ref))

    assert "Message ID:" in full.required_identifier_lines
    assert "Sender:" in full.required_identifier_lines
    assert "Message hash:" in ref.required_identifier_lines
    assert "Sender hash:" in ref.required_identifier_lines
  end

  test "copy and density scenarios keep blocked wording visible" do
    plan = LocalInboxUxTargetDeviceScenarioPlan.snapshot()

    assert plan.copy_review_scenarios.required_blocked_claims == [
             :delivery,
             :trusted_delivery,
             :routing,
             :background_operation
           ]

    assert :blocked_claims_called_out in plan.copy_review_scenarios.required_checks
    assert :detail_readability_reviewed in plan.visual_density_scenarios.required_checks
    assert :densest_fixture_captured in plan.visual_density_scenarios.required_checks
    assert :densest_fixture_artifact_path in plan.visual_density_scenarios.required_checks
    assert :densest_fixture_evidence_kind in plan.visual_density_scenarios.required_checks

    assert plan.visual_density_scenarios.densest_fixture_artifact_path ==
             "artifacts/local-ble/<run-id>/ux/visual-density-densest.png"

    assert plan.visual_density_scenarios.densest_fixture_evidence_kind == :screenshot
  end

  test "JSON snapshot is archiveable" do
    plan = LocalInboxUxTargetDeviceScenarioPlan.json_snapshot()

    assert plan["boundary"] == "nearby_messages_target_device_scenario_plan"
    assert plan["status"] == "open"
    assert length(plan["state_row_scenarios"]) == 4
    assert length(plan["selected_detail_scenarios"]) == 4
    assert plan["delivery_claim_allowed?"] == false
  end
end
