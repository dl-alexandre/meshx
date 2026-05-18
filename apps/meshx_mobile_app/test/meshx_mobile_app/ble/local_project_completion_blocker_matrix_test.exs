defmodule MeshxMobileApp.BLE.LocalProjectCompletionBlockerMatrixTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.LocalProjectCompletionBlockerMatrix

  test "snapshot classifies all ten open completion objectives" do
    snapshot = LocalProjectCompletionBlockerMatrix.snapshot()

    assert snapshot.boundary == :whole_project_completion_blocker_matrix
    refute snapshot.completion_claim_allowed?
    assert length(snapshot.entries) == 10

    assert Enum.map(snapshot.entries, & &1.objective_id) == [
             :full_message_resolution,
             :known_good_transport_validation,
             :multi_hop_hardware_proof,
             :product_ux,
             :persistence,
             :security_identity,
             :routing,
             :background_mobile_lifecycle,
             :ios_parity,
             :release_hardening
           ]
  end

  test "hardware-blocked objectives remain explicit" do
    snapshot = LocalProjectCompletionBlockerMatrix.snapshot()

    assert snapshot.blocked_by_new_hardware == [
             :full_message_resolution,
             :known_good_transport_validation,
             :multi_hop_hardware_proof,
             :ios_parity
           ]

    assert snapshot.primary_blocker_counts.hardware_evidence == 3
    assert snapshot.primary_blocker_counts.transport_selection == 1
    assert snapshot.category_counts.hardware_evidence == 6
  end

  test "non-hardware work can still progress without closing hardware blockers" do
    snapshot = LocalProjectCompletionBlockerMatrix.snapshot()

    assert snapshot.can_progress_without_new_hardware == [
             :product_ux,
             :persistence,
             :security_identity,
             :routing,
             :background_mobile_lifecycle,
             :release_hardening
           ]

    assert snapshot.primary_blocker_counts.product_decision == 3
    assert snapshot.primary_blocker_counts.release_evidence == 2
    assert snapshot.primary_blocker_counts.security_design == 1

    assert snapshot.next_action_summary.recommended_now.objective_id == :product_ux

    assert String.contains?(
             snapshot.next_action_summary.recommended_now.next_unblock_action,
             "limitation_copy"
           )

    assert Enum.any?(
             snapshot.next_action_summary.recommended_now.required_evidence,
             &String.contains?(&1, "coverage_summary")
           )
  end

  test "next action summary separates hardware and non-hardware unblock work" do
    snapshot = LocalProjectCompletionBlockerMatrix.snapshot()

    assert Enum.map(snapshot.next_action_summary.hardware_blocked, & &1.objective_id) ==
             snapshot.blocked_by_new_hardware

    assert Enum.map(
             snapshot.next_action_summary.can_progress_without_new_hardware,
             & &1.objective_id
           ) ==
             snapshot.can_progress_without_new_hardware
  end

  test "entries carry readiness status and concrete next unblock action" do
    entries = LocalProjectCompletionBlockerMatrix.entries()

    full_resolution = Enum.find(entries, &(&1.objective_id == :full_message_resolution))
    persistence = Enum.find(entries, &(&1.objective_id == :persistence))
    release = Enum.find(entries, &(&1.objective_id == :release_hardening))

    assert full_resolution.status == :blocked
    assert full_resolution.primary_blocker == :hardware_evidence
    refute full_resolution.can_progress_without_new_hardware?
    assert String.contains?(full_resolution.next_unblock_action, "fake/offline fetch")
    assert String.contains?(full_resolution.next_unblock_action, "real constrained transport")

    assert persistence.status == :partial
    assert persistence.primary_blocker == :product_decision
    assert persistence.can_progress_without_new_hardware?

    assert release.primary_blocker == :release_evidence
    assert :implementation in release.blocker_categories
    assert Enum.any?(release.required_evidence, &String.contains?(&1, "Release artifact bundle"))
    assert Enum.any?(release.required_evidence, &String.contains?(&1, "GenericJam/mob_dev#6"))
    assert String.contains?(release.next_unblock_action, "upstream PRs merge/release")
  end

  test "hardware-blocked recommendations preserve current blocker scope" do
    snapshot = LocalProjectCompletionBlockerMatrix.snapshot()

    known_good =
      Enum.find(snapshot.entries, &(&1.objective_id == :known_good_transport_validation))

    multi_hop = Enum.find(snapshot.entries, &(&1.objective_id == :multi_hop_hardware_proof))

    assert known_good.status == :blocked
    refute known_good.can_progress_without_new_hardware?
    assert String.contains?(known_good.next_unblock_action, "SM-T577U/SM-T390")
    assert String.contains?(known_good.next_unblock_action, "status 133")
    assert String.contains?(known_good.next_unblock_action, "standalone GATT")

    assert String.contains?(
             known_good.next_unblock_action,
             "different constrained fetch transport"
           )

    assert multi_hop.status == :blocked
    refute multi_hop.can_progress_without_new_hardware?
    assert String.contains?(multi_hop.next_unblock_action, "replay")
    assert String.contains?(multi_hop.next_unblock_action, "one-hop hardware evidence")
    assert String.contains?(multi_hop.next_unblock_action, "origin, relay, and observer")
    assert String.contains?(multi_hop.next_unblock_action, "three physical participants")
  end

  test "persistence recommendation requires explicit decision outcome" do
    snapshot = LocalProjectCompletionBlockerMatrix.snapshot()
    persistence = Enum.find(snapshot.entries, &(&1.objective_id == :persistence))

    assert persistence.status == :partial
    assert persistence.can_progress_without_new_hardware?
    assert String.contains?(persistence.next_unblock_action, "decision_outcome")
    assert String.contains?(persistence.next_unblock_action, "operator/release evidence")

    assert Enum.any?(
             persistence.required_evidence,
             &String.contains?(&1, "decision_outcome")
           )
  end

  test "product UX recommendation requires selected detail and coverage summary evidence" do
    snapshot = LocalProjectCompletionBlockerMatrix.snapshot()
    product_ux = Enum.find(snapshot.entries, &(&1.objective_id == :product_ux))

    assert product_ux.status == :partial
    assert product_ux.can_progress_without_new_hardware?
    assert String.contains?(product_ux.next_unblock_action, "Nearby Messages controls/copy")
    assert String.contains?(product_ux.next_unblock_action, "limitation_copy")
    assert String.contains?(product_ux.next_unblock_action, "next_action_copy")
    assert String.contains?(product_ux.next_unblock_action, "blocked_claim_copy")
    assert String.contains?(product_ux.next_unblock_action, "evidence_kind")
    assert String.contains?(product_ux.next_unblock_action, "coverage_summary")

    assert Enum.any?(
             product_ux.required_evidence,
             &String.contains?(&1, "evidence_kind")
           )

    assert Enum.any?(
             product_ux.required_evidence,
             &String.contains?(&1, "selected details")
           )

    assert Enum.any?(
             product_ux.required_evidence,
             &String.contains?(&1, "limitation_copy")
           )

    assert Enum.any?(
             product_ux.required_evidence,
             &String.contains?(&1, "next_action_copy")
           )

    assert Enum.any?(
             product_ux.required_evidence,
             &String.contains?(&1, "blocked_claim_copy")
           )

    assert Enum.any?(
             product_ux.required_evidence,
             &String.contains?(&1, "density-review")
           )
  end

  test "JSON snapshot preserves blocker categories" do
    snapshot = LocalProjectCompletionBlockerMatrix.json_snapshot()

    assert snapshot["boundary"] == "whole_project_completion_blocker_matrix"
    assert snapshot["completion_claim_allowed?"] == false
    assert snapshot["primary_blocker_counts"]["hardware_evidence"] == 3
    assert snapshot["primary_blocker_counts"]["transport_selection"] == 1
    assert "ios_parity" in snapshot["blocked_by_new_hardware"]
    assert "persistence" in snapshot["can_progress_without_new_hardware"]
    assert snapshot["next_action_summary"]["recommended_now"]["objective_id"] == "product_ux"

    assert snapshot["next_action_summary"]["recommended_now"]["next_unblock_action"] =~
             "coverage_summary"
  end
end
