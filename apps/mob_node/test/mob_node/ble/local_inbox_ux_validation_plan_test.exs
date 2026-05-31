defmodule Mob.Node.BLE.LocalInboxUxValidationPlanTest do
  use ExUnit.Case, async: true

  alias Mob.Node.BLE.LocalInboxUxValidationPlan

  test "snapshot keeps production UX blocked until on-device evidence exists" do
    snapshot = LocalInboxUxValidationPlan.snapshot()
    ids = Enum.map(snapshot.gates, & &1.id)

    assert snapshot.plan_version == 1
    assert snapshot.boundary == :nearby_messages_on_device_ux_validation
    assert snapshot.open_gate_count == 5
    assert snapshot.satisfied_gate_count == 0
    refute snapshot.production_ux_claim_allowed?
    assert :production_nearby_messages_ux in snapshot.blocked_claims

    assert :target_device_matrix in ids
    assert :state_coverage_screenshots in ids
    assert :interaction_coverage in ids
    assert :blocked_claim_copy_review in ids
    assert :visual_density_review in ids
  end

  test "target device matrix requires concrete device and build evidence" do
    gate = gate(:target_device_matrix)

    assert gate.status == :open
    assert :production_nearby_messages_ux in gate.blocked_claims

    assert Enum.any?(
             gate.required_evidence,
             &String.contains?(&1, "Device model, OS/API version")
           )

    assert Enum.any?(
             gate.acceptance_criteria,
             &String.contains?(&1, "names the target device and build")
           )
  end

  test "state coverage keeps beacon refs distinct from full messages" do
    gate = gate(:state_coverage_screenshots)

    assert :trusted_delivery in gate.blocked_claims

    assert Enum.any?(
             gate.required_evidence,
             &String.contains?(&1, "evidence_kind screenshot or operator_note")
           )

    assert Enum.any?(
             gate.required_evidence,
             &String.contains?(&1, "full message, unresolved ref, gossiped ref, and stale ref")
           )

    assert Enum.any?(
             gate.acceptance_criteria,
             &String.contains?(&1, "Beacon refs remain visually distinct")
           )
  end

  test "interaction coverage requires classified screenshot or note evidence" do
    gate = gate(:interaction_coverage)

    assert Enum.any?(
             gate.required_evidence,
             &String.contains?(&1, "Interaction evidence entries with evidence_kind")
           )

    assert Enum.any?(
             gate.required_evidence,
             &String.contains?(&1, "filter changes, sort changes, row selection")
           )
  end

  test "copy review blocks delivery and routing overclaims" do
    gate = gate(:blocked_claim_copy_review)

    assert :delivery in gate.blocked_claims
    assert :trusted_delivery in gate.blocked_claims
    assert :routing in gate.blocked_claims

    assert Enum.any?(
             gate.acceptance_criteria,
             &String.contains?(&1, "nearby/observed/ref wording")
           )
  end

  test "copy review requires control summaries and per-state blocked-claim copy" do
    gate = gate(:blocked_claim_copy_review)

    assert Enum.any?(
             gate.required_evidence,
             &String.contains?(&1, "Copy review entry with evidence_kind")
           )

    assert Enum.any?(
             gate.required_evidence,
             &String.contains?(&1, "filter/sort summaries")
           )

    assert Enum.any?(
             gate.required_evidence,
             &String.contains?(&1, "per-state blocked-claim copy")
           )

    assert Enum.any?(
             gate.acceptance_criteria,
             &String.contains?(&1, "Control summaries")
           )
  end

  test "visual density review requires classified screenshot and note evidence" do
    gate = gate(:visual_density_review)

    assert Enum.any?(
             gate.required_evidence,
             &String.contains?(&1, "evidence_kind operator_note")
           )

    assert Enum.any?(
             gate.required_evidence,
             &String.contains?(&1, "evidence_kind screenshot")
           )
  end

  test "json snapshot is machine readable" do
    snapshot = LocalInboxUxValidationPlan.json_snapshot()

    assert snapshot["plan_version"] == 1
    assert snapshot["production_ux_claim_allowed?"] == false
    assert Enum.any?(snapshot["gates"], &(&1["id"] == "visual_density_review"))
  end

  defp gate(id) do
    LocalInboxUxValidationPlan.snapshot().gates
    |> Enum.find(&(&1.id == id))
  end
end
