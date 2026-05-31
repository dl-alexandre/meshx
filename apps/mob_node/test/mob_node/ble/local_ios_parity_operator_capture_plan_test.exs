defmodule Mob.Node.BLE.LocalIOSParityOperatorCapturePlanTest do
  use ExUnit.Case, async: true

  alias Mob.Node.BLE.{
    LocalIOSParityHardwareEvidenceReview,
    LocalIOSParityOperatorCapturePlan
  }

  test "snapshot exposes iOS parity capture plan without enabling iOS claims" do
    plan = LocalIOSParityOperatorCapturePlan.snapshot()

    assert plan.boundary == :local_ios_parity_operator_capture_plan
    assert plan.status == :open
    assert plan.current_ios_mode == :contract_only
    refute plan.ios_hardware_evidence_complete?
    refute plan.ios_participation_claim_allowed?
    refute plan.ios_hardware_claim_allowed?
    refute plan.ios_legacy_beacon_observe_claim_allowed?
    refute plan.ios_legacy_beacon_gossip_claim_allowed?
    refute plan.ios_full_envelope_advert_claim_allowed?
    refute plan.ios_background_ble_claim_allowed?
    refute plan.ios_parity_claim_allowed?
  end

  test "capture sections cover every iOS hardware review gate" do
    plan = LocalIOSParityOperatorCapturePlan.snapshot()
    section_ids = Enum.map(plan.capture_sections, & &1.id)

    assert plan.required_gates == LocalIOSParityHardwareEvidenceReview.required_gates()
    assert plan.required_gates -- section_ids == []
    assert length(plan.capture_sections) == 8
  end

  test "each section has review fields evidence type and blocked claims" do
    plan = LocalIOSParityOperatorCapturePlan.snapshot()

    for section <- plan.capture_sections do
      assert section.review_section == section.id
      assert section.artifact_path =~ "artifacts/local-ble/<run-id>/ios/"
      assert :artifact_path in section.required_entries
      assert :summary in section.required_entries
      assert :test_command in section.required_entries
      assert :evidence_type in section.required_entries
      assert :blocked_claims_called_out in section.required_entries
      assert section.evidence_type == Map.fetch!(plan.required_evidence_types, section.id)
      assert plan.required_blocked_claims -- section.blocked_claims_called_out == []
      assert section.gate_specific_blocked_claims_called_out != []
    end
  end

  test "gossip and background sections preserve iOS parity boundaries" do
    plan = LocalIOSParityOperatorCapturePlan.snapshot()
    gossip = Enum.find(plan.capture_sections, &(&1.id == :legacy_beacon_gossip_hardware))
    background = Enum.find(plan.capture_sections, &(&1.id == :ios_background_ble_boundary))

    assert gossip.evidence_type == :legacy_beacon_gossip_hardware
    assert background.evidence_type == :ios_background_ble_boundary
    assert Enum.any?(gossip.notes, &String.contains?(&1, "without routing"))
    assert Enum.any?(background.notes, &String.contains?(&1, "separate Core Bluetooth"))
  end

  test "JSON snapshot is archiveable" do
    plan = LocalIOSParityOperatorCapturePlan.json_snapshot()

    assert plan["boundary"] == "local_ios_parity_operator_capture_plan"
    assert plan["status"] == "open"
    assert length(plan["capture_sections"]) == 8
    assert plan["ios_parity_claim_allowed?"] == false
  end
end
