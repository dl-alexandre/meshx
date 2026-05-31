defmodule Mob.Node.BLE.LocalInboxUxEvidenceManifestTest do
  use ExUnit.Case, async: true

  alias Mob.Node.BLE.LocalInboxUxEvidenceManifest

  test "snapshot packages Nearby Messages UX evidence without production claims" do
    manifest = LocalInboxUxEvidenceManifest.snapshot()

    assert manifest.manifest_version == 1
    assert manifest.boundary == :nearby_messages_ux_evidence_manifest
    assert manifest.fixture_freshness_policy.now == 100
    assert manifest.fixture_freshness_policy.stale_after_ms == 10
    refute manifest.production_ux_claim_allowed?
    refute manifest.delivery_claim_allowed?
    refute manifest.trusted_delivery_claim_allowed?
    refute manifest.routing_claim_allowed?

    assert manifest.fixture.nearby_message_count == 4
    assert manifest.surface.row_count == 4
    assert manifest.surface.filter_summary == "Showing all nearby observations (4)."
    assert manifest.surface.sort_summary == "Full messages, refs, gossip, then stale"

    assert [
             %{state: :full_message, label: "Full messages", count: 1},
             %{state: :unresolved_ref, label: "Unresolved refs", count: 1},
             %{state: :gossiped_ref, label: "Gossiped refs", count: 1},
             %{state: :stale_ref, label: "Stale refs", count: 1}
           ] = manifest.surface.sections

    assert manifest.validation_plan.open_gate_count == 5

    assert manifest.ux_decision_scenario_plan.boundary ==
             :nearby_messages_ux_decision_scenario_plan

    assert length(manifest.ux_decision_scenario_plan.decision_scenarios) == 2
    assert manifest.operator_capture_plan.boundary == :nearby_messages_operator_capture_plan
    assert length(manifest.operator_capture_plan.capture_sections) == 6

    assert manifest.target_device_scenario_plan.boundary ==
             :nearby_messages_target_device_scenario_plan

    assert length(manifest.target_device_scenario_plan.state_row_scenarios) == 4
    assert :production_nearby_messages_ux in manifest.blocked_claims
    assert Enum.any?(manifest.required_commands, &String.contains?(&1, "ux_validation_plan"))
    assert Enum.any?(manifest.required_commands, &String.contains?(&1, "local_inbox.ux_review"))
    assert Enum.any?(manifest.required_commands, &String.contains?(&1, "--template"))
  end

  test "fixture covers full, unresolved, gossiped, and stale states" do
    manifest = LocalInboxUxEvidenceManifest.snapshot()

    assert [:full_message, :unresolved_ref, :gossiped_ref, :stale_ref] -- manifest.fixture.states ==
             []

    assert [:full_message, :unresolved_ref, :gossiped_ref, :stale_ref] -- manifest.surface.states ==
             []

    assert manifest.acceptance.satisfied_count == 7
    assert manifest.acceptance.blocked_count == 1
  end

  test "surface summary exposes control descriptions and blocked-claim copy" do
    manifest = LocalInboxUxEvidenceManifest.snapshot()

    assert Enum.any?(
             manifest.surface.sort_descriptions,
             &(&1.sort == :strongest_rssi and &1.description == "Strongest signal first")
           )

    assert Enum.any?(
             manifest.surface.row_blocked_claims,
             &(&1.state == :unresolved_ref and "not fetch success" in &1.blocked_claims)
           )

    assert Enum.any?(
             manifest.surface.row_blocked_claims,
             &(&1.state == :gossiped_ref and "not multi-hop hardware proof" in &1.blocked_claims)
           )

    assert Enum.any?(
             manifest.surface.row_trust_decisions,
             &(&1.state == :full_message and &1.trust_summary == "Unsigned local observation" and
                 &1.trusted_message? == false)
           )

    assert Enum.any?(
             manifest.surface.row_trust_decisions,
             &(&1.state == :unresolved_ref and &1.trust_summary == "Untrusted hash reference" and
                 &1.delivery_claim_allowed? == false)
           )
  end

  test "affordance review ties filters sorting details and blocked claims together" do
    manifest = LocalInboxUxEvidenceManifest.snapshot()

    assert manifest.affordance_review.boundary == :nearby_messages_affordance_review
    assert manifest.affordance_review.filter_controls_present?
    assert manifest.affordance_review.sort_controls_present?
    assert manifest.affordance_review.selected_detail_all_states_covered?
    assert manifest.affordance_review.selected_detail_state_count == 4
    refute manifest.affordance_review.delivery_claim_allowed?
    refute manifest.affordance_review.production_ux_claim_allowed?

    assert [:full_message, :gossiped_ref, :stale_ref, :unresolved_ref] ==
             manifest.affordance_review.blocked_claim_copy_states
  end

  test "detail evidence summarizes selected rows for every state" do
    manifest = LocalInboxUxEvidenceManifest.snapshot()

    assert [:full_message, :unresolved_ref, :gossiped_ref, :stale_ref] --
             Enum.map(manifest.detail_evidence, & &1.state) == []

    assert Enum.all?(manifest.detail_evidence, &(&1.status == :selected))
    assert Enum.all?(manifest.detail_evidence, &(&1.delivery_claim_allowed? == false))
    assert Enum.all?(manifest.detail_evidence, & &1.limitation_present?)
    assert Enum.all?(manifest.detail_evidence, & &1.next_action_present?)

    full = Enum.find(manifest.detail_evidence, &(&1.state == :full_message))
    ref = Enum.find(manifest.detail_evidence, &(&1.state == :unresolved_ref))
    stale = Enum.find(manifest.detail_evidence, &(&1.state == :stale_ref))

    assert Enum.any?(full.identifier_lines, &String.starts_with?(&1, "Message ID:"))
    assert Enum.any?(full.identifier_lines, &String.starts_with?(&1, "Sender:"))
    assert Enum.any?(ref.identifier_lines, &String.starts_with?(&1, "Message hash:"))
    assert Enum.any?(ref.identifier_lines, &String.starts_with?(&1, "Sender hash:"))
    assert "not fetch success" in ref.blocked_claims
    assert stale.freshness_policy == manifest.fixture_freshness_policy
    assert "not current nearby presence" in stale.blocked_claims
  end

  test "manifest lists missing on-device evidence gates" do
    manifest = LocalInboxUxEvidenceManifest.snapshot()
    gate_ids = Enum.map(manifest.missing_on_device_evidence, & &1.gate_id)

    assert :target_device_matrix in gate_ids
    assert :state_coverage_screenshots in gate_ids
    assert :interaction_coverage in gate_ids
    assert :blocked_claim_copy_review in gate_ids
    assert :visual_density_review in gate_ids
  end

  test "missing on-device evidence gates name evidence_kind classification" do
    manifest = LocalInboxUxEvidenceManifest.snapshot()

    for gate_id <- [
          :state_coverage_screenshots,
          :interaction_coverage,
          :blocked_claim_copy_review,
          :visual_density_review
        ] do
      gate = Enum.find(manifest.missing_on_device_evidence, &(&1.gate_id == gate_id))

      assert Enum.any?(
               gate.required_evidence,
               &String.contains?(&1, "evidence_kind")
             )
    end
  end

  test "manifest requires copy review artifacts for control and blocked-claim anchors" do
    manifest = LocalInboxUxEvidenceManifest.snapshot()

    assert Enum.any?(manifest.missing_on_device_evidence, fn gate ->
             gate.gate_id == :blocked_claim_copy_review and
               Enum.any?(gate.required_evidence, &String.contains?(&1, "filter/sort summaries")) and
               Enum.any?(gate.required_evidence, &String.contains?(&1, "detail next actions")) and
               Enum.any?(
                 gate.required_evidence,
                 &String.contains?(&1, "per-state blocked-claim copy")
               )
           end)

    assert Enum.any?(manifest.required_artifacts, fn artifact ->
             artifact.id == :blocked_claim_copy_review and
               String.contains?(artifact.purpose, "evidence_kind") and
               String.contains?(artifact.purpose, "control summaries") and
               String.contains?(artifact.purpose, "limitation_copy") and
               String.contains?(artifact.purpose, "next_action_copy") and
               String.contains?(artifact.purpose, "blocked_claim_copy") and
               String.contains?(artifact.purpose, "selected_detail_evidence coverage") and
               String.contains?(artifact.purpose, "per-state blocked-claim copy")
           end)
  end

  test "manifest names selected-detail metadata in operator artifacts" do
    manifest = LocalInboxUxEvidenceManifest.snapshot()

    assert Enum.any?(manifest.required_artifacts, fn artifact ->
             artifact.id == :target_device_screenshots and
               String.contains?(artifact.purpose, "selected-detail states") and
               String.contains?(artifact.purpose, "interaction") and
               String.contains?(artifact.purpose, "evidence_kind") and
               String.contains?(artifact.purpose, "each state")
           end)

    assert Enum.any?(manifest.required_artifacts, fn artifact ->
             artifact.id == :ux_evidence_review and
               String.contains?(artifact.purpose, "selected-detail")
           end)

    assert Enum.any?(manifest.required_artifacts, fn artifact ->
             artifact.id == :ux_operator_capture_plan and
               String.contains?(artifact.purpose, "target-device capture checklist")
           end)

    assert Enum.any?(manifest.required_artifacts, fn artifact ->
             artifact.id == :ux_target_device_scenario_plan and
               String.contains?(artifact.purpose, "target-device UX scenarios")
           end)
  end

  test "required commands include query presenter state and action summary coverage" do
    manifest = LocalInboxUxEvidenceManifest.snapshot()

    for test_file <- [
          "local_inbox_query_test.exs",
          "local_inbox_ux_decision_scenario_plan_test.exs",
          "local_inbox_ux_target_device_scenario_plan_test.exs",
          "local_inbox_product_surface_test.exs",
          "local_inbox_presenter_test.exs",
          "local_inbox_state_copy_test.exs",
          "local_inbox_resolution_test.exs",
          "local_inbox_action_summary_test.exs"
        ] do
      assert Enum.any?(manifest.required_commands, &String.contains?(&1, test_file))
    end
  end

  test "JSON snapshot is machine readable and keeps delivery blocked" do
    manifest = LocalInboxUxEvidenceManifest.json_snapshot()

    assert manifest["boundary"] == "nearby_messages_ux_evidence_manifest"
    assert manifest["fixture_freshness_policy"]["now"] == 100
    assert manifest["fixture_freshness_policy"]["stale_after_ms"] == 10
    assert manifest["production_ux_claim_allowed?"] == false
    assert manifest["delivery_claim_allowed?"] == false
    assert manifest["trusted_delivery_claim_allowed?"] == false
    assert "trusted_delivery" in manifest["blocked_claims"]
    assert manifest["affordance_review"]["selected_detail_all_states_covered?"] == true

    assert manifest["ux_decision_scenario_plan"]["boundary"] ==
             "nearby_messages_ux_decision_scenario_plan"

    assert length(manifest["ux_decision_scenario_plan"]["decision_scenarios"]) == 2

    assert manifest["operator_capture_plan"]["boundary"] ==
             "nearby_messages_operator_capture_plan"

    assert length(manifest["operator_capture_plan"]["capture_sections"]) == 6

    assert manifest["target_device_scenario_plan"]["boundary"] ==
             "nearby_messages_target_device_scenario_plan"

    assert length(manifest["target_device_scenario_plan"]["selected_detail_scenarios"]) == 4

    assert Enum.any?(
             manifest["required_artifacts"],
             &(&1["id"] == "ux_validation_plan")
           )

    assert Enum.any?(
             manifest["required_artifacts"],
             &(&1["id"] == "ux_evidence_template")
           )

    assert Enum.any?(
             manifest["required_artifacts"],
             &(&1["id"] == "ux_evidence_review")
           )

    assert Enum.any?(
             manifest["required_artifacts"],
             &(&1["id"] == "ux_decision_scenario_plan")
           )

    assert Enum.any?(
             manifest["required_artifacts"],
             &(&1["id"] == "ux_operator_capture_plan")
           )

    assert Enum.any?(
             manifest["required_artifacts"],
             &(&1["id"] == "ux_target_device_scenario_plan")
           )
  end
end
