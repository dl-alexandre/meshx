defmodule MeshxMobileApp.BLE.LocalInboxUxEvidenceReviewTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.LocalInboxUxEvidenceReview

  test "empty evidence remains open and lists every UX gate family" do
    review = LocalInboxUxEvidenceReview.review(%{})

    assert review.review_version == 1
    assert review.boundary == :nearby_messages_on_device_ux_evidence
    assert review.status == :open
    refute review.on_device_ux_evidence_complete?
    refute review.production_ux_claim_allowed?
    refute review.delivery_claim_allowed?
    refute review.trusted_delivery_claim_allowed?
    refute review.routing_claim_allowed?
    assert review.coverage_summary.target_device_count == 0
    refute review.coverage_summary.all_target_devices_have_state_coverage?
    refute review.coverage_summary.all_target_devices_have_interaction_coverage?
    refute review.coverage_summary.all_target_devices_have_selected_detail_coverage?
    refute review.coverage_summary.all_target_devices_copy_reviewed?
    refute review.coverage_summary.all_target_devices_density_reviewed?

    assert Enum.any?(review.missing, &String.contains?(&1, "target device"))
    assert Enum.any?(review.missing, &String.contains?(&1, "state evidence"))
    assert Enum.any?(review.missing, &String.contains?(&1, "interaction evidence"))
    assert Enum.any?(review.missing, &String.contains?(&1, "selected detail evidence"))
    assert Enum.any?(review.missing, &String.contains?(&1, "Copy review"))
    assert Enum.any?(review.missing, &String.contains?(&1, "Visual density review"))
  end

  test "omitted top-level evidence sections are explicit" do
    review = LocalInboxUxEvidenceReview.review(%{})

    assert review.status == :open
    assert Enum.any?(review.missing, &String.contains?(&1, "Missing target_devices section."))
    assert Enum.any?(review.missing, &String.contains?(&1, "Missing state_evidence section."))

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "Missing interaction_evidence section.")
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "Missing selected_detail_evidence section.")
           )

    assert Enum.any?(review.missing, &String.contains?(&1, "Missing copy_review section."))

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "Missing visual_density_review section.")
           )
  end

  test "complete string-keyed metadata is ready without allowing delivery claims" do
    review = LocalInboxUxEvidenceReview.review(complete_json_input())

    assert review.status == :ready
    assert review.on_device_ux_evidence_complete?
    refute review.production_ux_claim_allowed?
    refute review.delivery_claim_allowed?
    assert review.missing == []

    assert Enum.map(review.state_evidence, & &1.state) ==
             LocalInboxUxEvidenceReview.required_states()

    assert Enum.map(review.interaction_evidence, & &1.interaction) ==
             LocalInboxUxEvidenceReview.required_interactions()

    assert review.coverage_summary.target_device_count == 1
    assert review.coverage_summary.state_evidence_count == 4
    assert review.coverage_summary.interaction_evidence_count == 4
    assert review.coverage_summary.selected_detail_evidence_count == 4
    assert review.coverage_summary.all_target_devices_have_state_coverage?
    assert review.coverage_summary.all_target_devices_have_interaction_coverage?
    assert review.coverage_summary.all_target_devices_have_selected_detail_coverage?
    assert review.coverage_summary.all_target_devices_have_selected_detail_copy_anchors?
    assert review.coverage_summary.all_target_devices_copy_reviewed?
    assert review.coverage_summary.all_target_devices_density_reviewed?
  end

  test "JSON review is machine readable and keeps claims blocked" do
    review = LocalInboxUxEvidenceReview.json_review(complete_json_input())

    assert review["status"] == "ready"
    assert review["on_device_ux_evidence_complete?"] == true
    assert review["production_ux_claim_allowed?"] == false
    assert review["delivery_claim_allowed?"] == false
    assert review["validation_plan"]["boundary"] == "nearby_messages_on_device_ux_validation"
    assert review["coverage_summary"]["target_device_count"] == 1
    assert review["coverage_summary"]["all_target_devices_have_state_coverage?"] == true
    assert review["coverage_summary"]["all_target_devices_have_selected_detail_coverage?"] == true
    assert review["coverage_summary"]["all_target_devices_have_selected_detail_copy_anchors?"] == true
    assert review["coverage_summary"]["all_target_devices_copy_reviewed?"] == true
  end

  test "JSON review does not expose internal validation flags" do
    review = LocalInboxUxEvidenceReview.json_review(complete_json_input())

    refute Map.has_key?(
             review["copy_review"],
             "target_device_ids_reviewed_container_valid?"
           )

    refute Map.has_key?(review["copy_review"], "target_device_ids_reviewed_present?")
    refute Map.has_key?(review["copy_review"], "blocked_claims_called_out_container_valid?")
    refute Map.has_key?(review["copy_review"], "blocked_claims_called_out_present?")
    refute Map.has_key?(review["copy_review"], "warning_text_captured_present?")
    refute Map.has_key?(review["copy_review"], "control_summaries_captured_present?")
    refute Map.has_key?(review["copy_review"], "state_blocked_claim_copy_captured_present?")
    refute Map.has_key?(review["copy_review"], "detail_panel_copy_captured_present?")

    refute Map.has_key?(
             review["visual_density_review"],
             "target_device_ids_reviewed_container_valid?"
           )

    refute Map.has_key?(review["visual_density_review"], "target_device_ids_reviewed_present?")
    refute Map.has_key?(review["visual_density_review"], "row_truncation_reviewed_present?")
    refute Map.has_key?(review["visual_density_review"], "wrapping_reviewed_present?")
    refute Map.has_key?(review["visual_density_review"], "tap_targets_reviewed_present?")
    refute Map.has_key?(review["visual_density_review"], "detail_readability_reviewed_present?")
    refute Map.has_key?(review["visual_density_review"], "densest_fixture_captured_present?")
  end

  test "JSON review fails closed for malformed top-level input" do
    review = LocalInboxUxEvidenceReview.json_review("not-a-map")

    assert review["status"] == "open"
    assert review["on_device_ux_evidence_complete?"] == false

    assert Enum.any?(
             review["missing"],
             &String.contains?(&1, "Missing at least one target device")
           )
  end

  test "template input lists required UX evidence but cannot pass as complete evidence" do
    template = LocalInboxUxEvidenceReview.template_input()

    assert Enum.map(template["state_evidence"], & &1["state"]) ==
             Enum.map(LocalInboxUxEvidenceReview.required_states(), &Atom.to_string/1)

    assert Enum.map(template["interaction_evidence"], & &1["interaction"]) ==
             Enum.map(LocalInboxUxEvidenceReview.required_interactions(), &Atom.to_string/1)

    assert Enum.all?(template["interaction_evidence"], &Map.has_key?(&1, "evidence_kind"))
    assert Enum.all?(template["selected_detail_evidence"], &Map.has_key?(&1, "evidence_kind"))
    assert Enum.all?(template["selected_detail_evidence"], &Map.has_key?(&1, "limitation_copy"))
    assert Enum.all?(template["selected_detail_evidence"], &Map.has_key?(&1, "next_action_copy"))

    assert Enum.all?(
             template["selected_detail_evidence"],
             &Map.has_key?(&1, "blocked_claim_copy")
           )

    assert Map.has_key?(template["copy_review"], "evidence_kind")
    assert Map.has_key?(template["visual_density_review"], "evidence_kind")
    assert Map.has_key?(template["visual_density_review"], "densest_fixture_artifact_path")
    assert Map.has_key?(template["visual_density_review"], "densest_fixture_evidence_kind")

    review = LocalInboxUxEvidenceReview.review(template)

    assert review.status == :open
    refute review.on_device_ux_evidence_complete?
    assert Enum.any?(review.missing, &String.contains?(&1, "Target device 1"))
    assert Enum.any?(review.missing, &String.contains?(&1, "Visual density review"))
  end

  test "malformed metadata identifies missing state, interaction, copy, and density coverage" do
    input =
      complete_json_input()
      |> Map.put("state_evidence", [])
      |> Map.put("interaction_evidence", [])
      |> put_in(["copy_review", "blocked_claims_called_out"], ["delivery"])
      |> put_in(["visual_density_review", "tap_targets_reviewed"], false)

    review = LocalInboxUxEvidenceReview.review(input)

    assert review.status == :open
    assert Enum.any?(review.missing, &String.contains?(&1, "Missing state evidence"))
    assert Enum.any?(review.missing, &String.contains?(&1, "Missing interaction evidence"))
    assert Enum.any?(review.missing, &String.contains?(&1, "blocked claim callouts"))
    assert Enum.any?(review.missing, &String.contains?(&1, "tap target review"))
  end

  test "malformed top-level evidence fails closed instead of raising" do
    review = LocalInboxUxEvidenceReview.review("not-a-map")

    assert review.status == :open
    assert Enum.any?(review.missing, &String.contains?(&1, "Missing at least one target device"))
    assert Enum.any?(review.missing, &String.contains?(&1, "Missing state evidence"))
    assert Enum.any?(review.missing, &String.contains?(&1, "Missing interaction evidence"))
  end

  test "malformed evidence containers fail closed instead of raising" do
    input =
      complete_json_input()
      |> Map.put("target_devices", "not-a-list")
      |> Map.put("state_evidence", "not-a-list")
      |> Map.put("interaction_evidence", "not-a-list")
      |> Map.put("copy_review", "not-a-map")
      |> Map.put("visual_density_review", "not-a-map")

    review = LocalInboxUxEvidenceReview.review(input)

    assert review.status == :open
    assert Enum.any?(review.missing, &String.contains?(&1, "target_devices must be a list."))
    assert Enum.any?(review.missing, &String.contains?(&1, "state_evidence must be a list."))

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "interaction_evidence must be a list.")
           )

    assert Enum.any?(review.missing, &String.contains?(&1, "copy_review must be an object."))

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "visual_density_review must be an object.")
           )

    assert Enum.any?(review.missing, &String.contains?(&1, "Missing at least one target device"))
    assert Enum.any?(review.missing, &String.contains?(&1, "Missing state evidence"))
    assert Enum.any?(review.missing, &String.contains?(&1, "Missing interaction evidence"))
    assert Enum.any?(review.missing, &String.contains?(&1, "Copy review missing review_path"))
    assert Enum.any?(review.missing, &String.contains?(&1, "Visual density review missing"))
  end

  test "copy review must capture current control summaries and state blocked-claim copy" do
    input =
      complete_json_input()
      |> put_in(["copy_review", "control_summaries_captured"], false)
      |> put_in(["copy_review", "state_blocked_claim_copy_captured"], false)
      |> put_in(["copy_review", "detail_panel_copy_captured"], false)

    review = LocalInboxUxEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "Copy review must capture filter and sort control summaries.")
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "Copy review must capture per-state blocked-claim copy.")
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "Copy review must capture selected detail panel limitation, next-action, and blocked-claim copy."
             )
           )
  end

  test "selected detail evidence must declare screenshot or operator note evidence kind" do
    input =
      complete_json_input()
      |> update_in(["selected_detail_evidence"], fn [first | rest] ->
        [
          first
          |> Map.delete("evidence_kind")
          |> Map.put("artifact_path", "artifacts/local-ble/run/ux/missing-kind.png")
          | rest
        ]
      end)

    review = LocalInboxUxEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "Selected detail evidence 1 missing evidence_kind.")
           )

    input =
      complete_json_input()
      |> put_in(["selected_detail_evidence", Access.at(0), "evidence_kind"], "screenrecording")

    review = LocalInboxUxEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               ~s(Selected detail evidence 1 has unsupported evidence_kind "screenrecording")
             )
           )
  end

  test "selected detail evidence must capture limitation next action and blocked claim copy" do
    input =
      complete_json_input()
      |> update_in(["selected_detail_evidence"], fn [first | rest] ->
        [
          first
          |> Map.delete("limitation_copy")
          |> Map.delete("next_action_copy")
          |> Map.delete("blocked_claim_copy")
          | rest
        ]
      end)

    review = LocalInboxUxEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "Selected detail evidence 1 missing limitation_copy.")
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "Selected detail evidence 1 missing next_action_copy.")
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "Selected detail evidence 1 missing blocked_claim_copy.")
           )

    input =
      complete_json_input()
      |> put_in(["selected_detail_evidence", Access.at(0), "limitation_copy"], "  not trusted")
      |> put_in(["selected_detail_evidence", Access.at(0), "next_action_copy"], 42)
      |> put_in(["selected_detail_evidence", Access.at(0), "blocked_claim_copy"], "delivery ")

    review = LocalInboxUxEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "Selected detail evidence 1 limitation_copy must not have leading or trailing whitespace."
             )
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "Selected detail evidence 1 next_action_copy must be a string."
             )
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "Selected detail evidence 1 blocked_claim_copy must not have leading or trailing whitespace."
             )
           )
  end

  test "interaction evidence must declare screenshot or operator note evidence kind" do
    input =
      complete_json_input()
      |> update_in(["interaction_evidence"], fn [first | rest] ->
        [
          first
          |> Map.delete("evidence_kind")
          |> Map.put("artifact_path", "artifacts/local-ble/run/ux/missing-interaction-kind.png")
          | rest
        ]
      end)

    review = LocalInboxUxEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "Interaction evidence 1 missing evidence_kind.")
           )

    input =
      complete_json_input()
      |> put_in(["interaction_evidence", Access.at(0), "evidence_kind"], "screenrecording")

    review = LocalInboxUxEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               ~s(Interaction evidence 1 has unsupported evidence_kind "screenrecording")
             )
           )
  end

  test "copy and density reviews must declare screenshot or operator note evidence kind" do
    input =
      complete_json_input()
      |> update_in(["copy_review"], &Map.delete(&1, "evidence_kind"))
      |> update_in(["visual_density_review"], &Map.delete(&1, "evidence_kind"))

    review = LocalInboxUxEvidenceReview.review(input)

    assert review.status == :open
    assert Enum.any?(review.missing, &String.contains?(&1, "Copy review missing evidence_kind."))

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "Visual density review missing evidence_kind.")
           )

    input =
      complete_json_input()
      |> put_in(["copy_review", "evidence_kind"], "claim_only")
      |> put_in(["visual_density_review", "evidence_kind"], "screenrecording")

    review = LocalInboxUxEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, ~s(Copy review has unsupported evidence_kind "claim_only"))
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               ~s(Visual density review has unsupported evidence_kind "screenrecording")
             )
           )
  end

  test "malformed evidence rows fail closed as missing fields" do
    input =
      complete_json_input()
      |> Map.put("target_devices", ["not-a-map"])
      |> Map.put("state_evidence", ["not-a-map"])
      |> Map.put("interaction_evidence", ["not-a-map"])

    review = LocalInboxUxEvidenceReview.review(input)

    assert review.status == :open
    assert Enum.any?(review.missing, &String.contains?(&1, "Target device 1 must be an object."))
    assert Enum.any?(review.missing, &String.contains?(&1, "State evidence 1 must be an object."))

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "Interaction evidence 1 must be an object.")
           )

    assert Enum.any?(review.missing, &String.contains?(&1, "Target device 1 missing device_id"))
    assert Enum.any?(review.missing, &String.contains?(&1, "State evidence 1 missing state"))

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "Interaction evidence 1 missing interaction")
           )
  end

  test "malformed scalar evidence fields fail closed instead of passing presence checks" do
    input =
      complete_json_input()
      |> put_in(["target_devices", Access.at(0), "device_id"], 390)
      |> put_in(["target_devices", Access.at(0), "device_model"], 577)
      |> put_in(["target_devices", Access.at(0), "os_or_api_version"], 28)
      |> put_in(["target_devices", Access.at(0), "screen_size_class"], :tablet)
      |> put_in(["target_devices", Access.at(0), "app_build_id"], 20_260_513)
      |> put_in(["target_devices", Access.at(0), "evidence_path"], 123)
      |> put_in(["state_evidence", Access.at(0), "target_device_id"], 390)
      |> put_in(["state_evidence", Access.at(0), "artifact_path"], 456)
      |> put_in(["state_evidence", Access.at(0), "notes"], 789)
      |> put_in(["interaction_evidence", Access.at(0), "target_device_id"], 390)
      |> put_in(["interaction_evidence", Access.at(0), "artifact_path"], 456)
      |> put_in(["interaction_evidence", Access.at(0), "notes"], 789)
      |> put_in(["copy_review", "review_path"], 123)
      |> put_in(["visual_density_review", "artifact_path"], 456)
      |> put_in(["visual_density_review", "densest_fixture_artifact_path"], 789)

    review = LocalInboxUxEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "Target device 1 device_id must be a string.")
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "Target device 1 device_model must be a string.")
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "Target device 1 os_or_api_version must be a string.")
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "Target device 1 screen_size_class must be a string.")
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "Target device 1 app_build_id must be a string.")
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "Target device 1 evidence_path must be a string.")
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "State evidence 1 target_device_id must be a string.")
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "State evidence 1 artifact_path must be a string.")
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "State evidence 1 notes must be a string.")
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "Interaction evidence 1 target_device_id must be a string.")
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "Interaction evidence 1 artifact_path must be a string.")
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "Interaction evidence 1 notes must be a string.")
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "Copy review review_path must be a string.")
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "Visual density review artifact_path must be a string.")
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "Visual density review densest_fixture_artifact_path must be a string."
             )
           )
  end

  test "malformed enum evidence fields fail closed instead of only reporting unsupported values" do
    input =
      complete_json_input()
      |> put_in(["state_evidence", Access.at(0), "state"], 123)
      |> put_in(["state_evidence", Access.at(0), "evidence_kind"], 456)
      |> put_in(["interaction_evidence", Access.at(0), "interaction"], 789)
      |> put_in(["copy_review", "evidence_kind"], 123)
      |> put_in(["visual_density_review", "evidence_kind"], 456)
      |> put_in(["visual_density_review", "densest_fixture_evidence_kind"], 789)

    review = LocalInboxUxEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "State evidence 1 state must be a string or atom.")
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "State evidence 1 evidence_kind must be a string or atom.")
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "Interaction evidence 1 interaction must be a string or atom.")
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "Copy review evidence_kind must be a string or atom.")
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "Visual density review evidence_kind must be a string or atom."
             )
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "Visual density review densest_fixture_evidence_kind must be a string or atom."
             )
           )
  end

  test "enum evidence fields must not need trimming" do
    input =
      complete_json_input()
      |> put_in(["state_evidence", Access.at(0), "state"], " full_message")
      |> put_in(["state_evidence", Access.at(0), "evidence_kind"], "screenshot ")
      |> put_in(["interaction_evidence", Access.at(0), "interaction"], " filter_change")

    review = LocalInboxUxEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "State evidence 1 state must not have leading or trailing whitespace."
             )
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "State evidence 1 evidence_kind must not have leading or trailing whitespace."
             )
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "Interaction evidence 1 interaction must not have leading or trailing whitespace."
             )
           )
  end

  test "target device ids must be unique" do
    input =
      complete_json_input()
      |> update_in(["target_devices"], fn [device] ->
        [device, Map.put(device, "device_model", "Duplicate SM-T390 row")]
      end)

    review = LocalInboxUxEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, ~s(Duplicate target device ids: ["sm-t390"]))
           )
  end

  test "target device evidence paths must be unique" do
    input =
      complete_json_input()
      |> update_in(["target_devices"], fn [device] ->
        [
          device,
          device
          |> Map.put("device_id", "pixel-8")
          |> Map.put("device_model", "Pixel 8")
        ]
      end)

    review = LocalInboxUxEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               ~s(Duplicate target device evidence paths: ["artifacts/local-ble/run/ux/sm-t390/"])
             )
           )
  end

  test "state and interaction artifact paths must be unique" do
    input =
      complete_json_input()
      |> update_in(["state_evidence"], fn [first, second | rest] ->
        [first, Map.put(second, "artifact_path", first["artifact_path"]) | rest]
      end)
      |> update_in(["interaction_evidence"], fn [first, second | rest] ->
        [first, Map.put(second, "artifact_path", first["artifact_path"]) | rest]
      end)

    review = LocalInboxUxEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               ~s(State evidence has duplicate artifact paths: ["artifacts/local-ble/run/ux/full_message.png"])
             )
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               ~s(Interaction evidence has duplicate artifact paths: ["artifacts/local-ble/run/ux/filter_change.png"])
             )
           )
  end

  test "state and interaction evidence must use separate artifact paths" do
    input =
      complete_json_input()
      |> update_in(["interaction_evidence"], fn [first | rest] ->
        [
          Map.put(first, "artifact_path", "artifacts/local-ble/run/ux/full_message.png")
          | rest
        ]
      end)

    review = LocalInboxUxEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               ~s(State and interaction evidence share artifact paths: ["artifacts/local-ble/run/ux/full_message.png"])
             )
           )
  end

  test "state and interaction evidence must not duplicate target coverage" do
    input =
      complete_json_input()
      |> update_in(["state_evidence"], fn [first | rest] ->
        [
          first,
          Map.put(first, "artifact_path", "artifacts/local-ble/run/ux/full_message_2.png")
          | rest
        ]
      end)
      |> update_in(["interaction_evidence"], fn [first | rest] ->
        [
          first,
          Map.put(first, "artifact_path", "artifacts/local-ble/run/ux/filter_change_2.png")
          | rest
        ]
      end)

    review = LocalInboxUxEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               ~s(State evidence has duplicate target coverage: [{"sm-t390", :full_message}])
             )
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               ~s(Interaction evidence has duplicate target coverage: [{"sm-t390", :filter_change}])
             )
           )
  end

  test "state and interaction evidence must use supported values" do
    input =
      complete_json_input()
      |> update_in(["state_evidence"], fn evidence ->
        [
          %{
            "state" => "unknown_state",
            "target_device_id" => "sm-t390",
            "evidence_kind" => "screenshot",
            "artifact_path" => "artifacts/local-ble/run/ux/unknown-state.png",
            "notes" => "unknown state row should not be accepted"
          }
          | evidence
        ]
      end)
      |> update_in(["interaction_evidence"], fn evidence ->
        [
          %{
            "interaction" => "unknown_interaction",
            "target_device_id" => "sm-t390",
            "artifact_path" => "artifacts/local-ble/run/ux/unknown-interaction.png",
            "notes" => "unknown interaction should not be accepted"
          }
          | evidence
        ]
      end)

    review = LocalInboxUxEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               ~s(State evidence has unsupported state values: ["unknown_state"])
             )
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               ~s(Interaction evidence has unsupported interaction values: ["unknown_interaction"])
             )
           )
  end

  test "copy and visual density reviews must use separate artifact paths" do
    input =
      complete_json_input()
      |> put_in(
        ["visual_density_review", "artifact_path"],
        "artifacts/local-ble/run/ux/copy-review.md"
      )

    review = LocalInboxUxEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "Copy review and visual density review must use separate artifact paths:"
             )
           )

    input =
      complete_json_input()
      |> put_in(
        ["visual_density_review", "densest_fixture_artifact_path"],
        "artifacts/local-ble/run/ux/density.md"
      )

    review = LocalInboxUxEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "Copy review and visual density review must use separate artifact paths:"
             )
           )
  end

  test "copy and density review artifacts cannot reuse evidence artifact paths" do
    input =
      complete_json_input()
      |> put_in(["copy_review", "review_path"], "artifacts/local-ble/run/ux/full_message.png")
      |> put_in(
        ["visual_density_review", "artifact_path"],
        "artifacts/local-ble/run/ux/filter_change.png"
      )
      |> put_in(
        ["visual_density_review", "densest_fixture_artifact_path"],
        "artifacts/local-ble/run/ux/selected-detail-stale_ref.png"
      )

    review = LocalInboxUxEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               ~s(Review artifacts reuse state or interaction evidence paths: ["artifacts/local-ble/run/ux/filter_change.png", "artifacts/local-ble/run/ux/full_message.png", "artifacts/local-ble/run/ux/selected-detail-stale_ref.png"])
             )
           )
  end

  test "visual density review requires a separate densest fixture screenshot artifact" do
    input =
      complete_json_input()
      |> update_in(["visual_density_review"], &Map.delete(&1, "densest_fixture_artifact_path"))

    review = LocalInboxUxEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "Visual density review missing densest_fixture_artifact_path."
             )
           )
  end

  test "visual density densest fixture evidence kind must be screenshot" do
    input =
      complete_json_input()
      |> update_in(
        ["visual_density_review"],
        &Map.delete(&1, "densest_fixture_evidence_kind")
      )

    review = LocalInboxUxEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "Visual density review missing densest_fixture_evidence_kind."
             )
           )

    input =
      complete_json_input()
      |> put_in(["visual_density_review", "densest_fixture_evidence_kind"], "operator_note")

    review = LocalInboxUxEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "Visual density review densest_fixture_evidence_kind must be screenshot."
             )
           )
  end

  test "evidence artifact paths must be release-relative" do
    input =
      complete_json_input()
      |> put_in(["target_devices", Access.at(0), "evidence_path"], "/tmp/ux/sm-t390")
      |> put_in(["state_evidence", Access.at(0), "artifact_path"], "../outside/full-message.png")
      |> put_in(["interaction_evidence", Access.at(0), "artifact_path"], "file:///tmp/filter.png")
      |> put_in(["copy_review", "review_path"], "https://example.invalid/copy.md")
      |> put_in(["visual_density_review", "artifact_path"], "~/density.md")
      |> put_in(
        ["visual_density_review", "densest_fixture_artifact_path"],
        "/tmp/densest.png"
      )

    review = LocalInboxUxEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "Target device 1 evidence_path must be a relative artifact path."
             )
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "State evidence 1 artifact_path must be a relative artifact path."
             )
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "Interaction evidence 1 artifact_path must be a relative artifact path."
             )
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "Copy review review_path must be a relative artifact path.")
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "Visual density review artifact_path must be a relative artifact path."
             )
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "Visual density review densest_fixture_artifact_path must be a relative artifact path."
             )
           )
  end

  test "evidence artifact paths must not need trimming" do
    input =
      complete_json_input()
      |> put_in(
        ["target_devices", Access.at(0), "evidence_path"],
        " artifacts/local-ble/run/ux/sm-t390/"
      )
      |> put_in(
        ["state_evidence", Access.at(0), "artifact_path"],
        "artifacts/local-ble/run/ux/full_message.png "
      )
      |> put_in(
        ["interaction_evidence", Access.at(0), "artifact_path"],
        " artifacts/local-ble/run/ux/filter_change.png"
      )
      |> put_in(["copy_review", "review_path"], "artifacts/local-ble/run/ux/copy-review.md ")
      |> put_in(
        ["visual_density_review", "artifact_path"],
        " artifacts/local-ble/run/ux/density.md"
      )
      |> put_in(
        ["visual_density_review", "densest_fixture_artifact_path"],
        "artifacts/local-ble/run/ux/densest.png "
      )
      |> put_in(["visual_density_review", "densest_fixture_evidence_kind"], "screenshot ")

    review = LocalInboxUxEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "Target device 1 evidence_path must not have leading or trailing whitespace."
             )
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "State evidence 1 artifact_path must not have leading or trailing whitespace."
             )
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "Interaction evidence 1 artifact_path must not have leading or trailing whitespace."
             )
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "Copy review review_path must not have leading or trailing whitespace."
             )
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "Visual density review artifact_path must not have leading or trailing whitespace."
             )
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "Visual density review densest_fixture_artifact_path must not have leading or trailing whitespace."
             )
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "Visual density review densest_fixture_evidence_kind must not have leading or trailing whitespace."
             )
           )
  end

  test "target device identity fields must not need trimming" do
    input =
      complete_json_input()
      |> put_in(["target_devices", Access.at(0), "device_id"], " sm-t390")
      |> put_in(["state_evidence", Access.at(0), "target_device_id"], "sm-t390 ")
      |> put_in(["interaction_evidence", Access.at(0), "target_device_id"], " sm-t390")
      |> put_in(["copy_review", "target_device_ids_reviewed"], ["sm-t390 "])
      |> put_in(["visual_density_review", "target_device_ids_reviewed"], [" sm-t390"])

    review = LocalInboxUxEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "Target device 1 device_id must not have leading or trailing whitespace."
             )
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "State evidence 1 target_device_id must not have leading or trailing whitespace."
             )
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "Interaction evidence 1 target_device_id must not have leading or trailing whitespace."
             )
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               ~s(Copy review target_device_ids_reviewed must not contain ids with leading or trailing whitespace: ["sm-t390 "])
             )
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               ~s(Visual density review target_device_ids_reviewed must not contain ids with leading or trailing whitespace: [" sm-t390"])
             )
           )
  end

  test "target device and evidence note text must not need trimming" do
    input =
      complete_json_input()
      |> put_in(["target_devices", Access.at(0), "device_model"], " SM-T390")
      |> put_in(["target_devices", Access.at(0), "os_or_api_version"], "Android API 28 ")
      |> put_in(["target_devices", Access.at(0), "screen_size_class"], " small_tablet")
      |> put_in(
        ["target_devices", Access.at(0), "app_build_id"],
        "meshx-local-debug-2026-05-13 "
      )
      |> put_in(["state_evidence", Access.at(0), "notes"], " full message row visible")
      |> put_in(["interaction_evidence", Access.at(0), "notes"], "filter change usable ")

    review = LocalInboxUxEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "Target device 1 device_model must not have leading or trailing whitespace."
             )
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "Target device 1 os_or_api_version must not have leading or trailing whitespace."
             )
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "Target device 1 screen_size_class must not have leading or trailing whitespace."
             )
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "Target device 1 app_build_id must not have leading or trailing whitespace."
             )
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "State evidence 1 notes must not have leading or trailing whitespace."
             )
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "Interaction evidence 1 notes must not have leading or trailing whitespace."
             )
           )
  end

  test "windows absolute evidence paths are not archive-relative" do
    input =
      complete_json_input()
      |> put_in(["state_evidence", Access.at(0), "artifact_path"], "C:\\tmp\\full-message.png")
      |> put_in(
        ["interaction_evidence", Access.at(0), "artifact_path"],
        "\\\\share\\ux\\filter.png"
      )

    review = LocalInboxUxEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "State evidence 1 artifact_path must be a relative artifact path."
             )
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "Interaction evidence 1 artifact_path must be a relative artifact path."
             )
           )
  end

  test "copy review must name every declared target device" do
    input =
      complete_json_input()
      |> add_pixel_8_target_with_evidence()

    review = LocalInboxUxEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, ~s(Copy review missing target devices: ["pixel-8"]))
           )
  end

  test "visual density review must name every declared target device" do
    input =
      complete_json_input()
      |> add_pixel_8_target_with_evidence()
      |> update_in(["copy_review", "target_device_ids_reviewed"], &["pixel-8" | &1])
      |> put_in(["visual_density_review", "target_device_ids_reviewed"], ["sm-t390"])

    review = LocalInboxUxEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, ~s(Visual density review missing target devices: ["pixel-8"]))
           )
  end

  test "copy and density reviews cannot name undeclared target devices" do
    input =
      complete_json_input()
      |> update_in(["copy_review", "target_device_ids_reviewed"], &["unknown-device" | &1])
      |> update_in(
        ["visual_density_review", "target_device_ids_reviewed"],
        &["unknown-device" | &1]
      )

    review = LocalInboxUxEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               ~s(Copy review references undeclared target devices: ["unknown-device"])
             )
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               ~s(Visual density review references undeclared target devices: ["unknown-device"])
             )
           )
  end

  test "copy and density reviews cannot duplicate reviewed target devices" do
    input =
      complete_json_input()
      |> update_in(["copy_review", "target_device_ids_reviewed"], &["sm-t390" | &1])
      |> update_in(["visual_density_review", "target_device_ids_reviewed"], &["sm-t390" | &1])

    review = LocalInboxUxEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               ~s(Copy review has duplicate reviewed target devices: ["sm-t390"])
             )
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               ~s(Visual density review has duplicate reviewed target devices: ["sm-t390"])
             )
           )
  end

  test "copy and density reviewed target lists cannot contain malformed ids" do
    input =
      complete_json_input()
      |> update_in(["copy_review", "target_device_ids_reviewed"], &["", 123 | &1])
      |> update_in(["visual_density_review", "target_device_ids_reviewed"], &[nil, " " | &1])

    review = LocalInboxUxEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               ~s(Copy review target_device_ids_reviewed must contain only non-empty strings: [123, ""])
             )
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               ~s(Visual density review target_device_ids_reviewed must contain only non-empty strings: [nil, " "])
             )
           )
  end

  test "copy and density reviewed target containers must be lists" do
    input =
      complete_json_input()
      |> put_in(["copy_review", "target_device_ids_reviewed"], "sm-t390")
      |> put_in(["visual_density_review", "target_device_ids_reviewed"], "sm-t390")

    review = LocalInboxUxEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "Copy review target_device_ids_reviewed must be a list.")
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "Visual density review target_device_ids_reviewed must be a list."
             )
           )
  end

  test "copy and density review list fields must be explicit" do
    input =
      complete_json_input()
      |> update_in(["copy_review"], fn review ->
        review
        |> Map.delete("target_device_ids_reviewed")
        |> Map.delete("blocked_claims_called_out")
        |> Map.delete("control_summaries_captured")
        |> Map.delete("state_blocked_claim_copy_captured")
      end)
      |> update_in(["visual_density_review"], &Map.delete(&1, "target_device_ids_reviewed"))

    review = LocalInboxUxEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "Copy review missing target_device_ids_reviewed.")
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "Copy review missing blocked_claims_called_out.")
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "Copy review missing control_summaries_captured.")
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "Copy review missing state_blocked_claim_copy_captured.")
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "Visual density review missing target_device_ids_reviewed."
             )
           )
  end

  test "copy review blocked claim callouts must be exact" do
    input =
      complete_json_input()
      |> update_in(["copy_review", "blocked_claims_called_out"], fn claims ->
        ["delivery", "unsupported_claim" | claims]
      end)

    review = LocalInboxUxEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               ~s(Copy review has unsupported blocked claim callouts: ["unsupported_claim"])
             )
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "Copy review has duplicate blocked claim callouts: [:delivery]"
             )
           )
  end

  test "copy review blocked claim callout container must be a list" do
    input =
      complete_json_input()
      |> put_in(["copy_review", "blocked_claims_called_out"], "delivery")

    review = LocalInboxUxEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "Copy review blocked_claims_called_out must be a list.")
           )
  end

  test "copy review allowed wording must be a string" do
    input =
      complete_json_input()
      |> put_in(["copy_review", "allowed_wording"], 123)

    review = LocalInboxUxEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "Copy review allowed_wording must be a string.")
           )
  end

  test "copy review allowed wording must be explicit" do
    input =
      complete_json_input()
      |> update_in(["copy_review"], &Map.delete(&1, "allowed_wording"))

    review = LocalInboxUxEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "Copy review missing allowed_wording.")
           )
  end

  test "copy review allowed wording must not need trimming" do
    input =
      complete_json_input()
      |> put_in(
        ["copy_review", "allowed_wording"],
        " #{LocalInboxUxEvidenceReview.allowed_wording()}"
      )

    review = LocalInboxUxEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "Copy review allowed_wording must not have leading or trailing whitespace."
             )
           )
  end

  test "copy review blocked claim callouts cannot contain malformed values" do
    input =
      complete_json_input()
      |> update_in(["copy_review", "blocked_claims_called_out"], &["", 123 | &1])

    review = LocalInboxUxEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               ~s(Copy review blocked_claims_called_out must contain only non-empty strings or atoms: [123, ""])
             )
           )
  end

  test "copy review blocked claim callouts must not need trimming" do
    input =
      complete_json_input()
      |> update_in(["copy_review", "blocked_claims_called_out"], fn claims ->
        [" delivery", "routing " | claims]
      end)

    review = LocalInboxUxEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               ~s(Copy review blocked_claims_called_out must not contain claims with leading or trailing whitespace: [" delivery", "routing "])
             )
           )
  end

  test "copy and density boolean review fields must be booleans" do
    input =
      complete_json_input()
      |> put_in(["copy_review", "warning_text_captured"], "true")
      |> put_in(["copy_review", "control_summaries_captured"], "true")
      |> put_in(["copy_review", "state_blocked_claim_copy_captured"], "true")
      |> put_in(["copy_review", "detail_panel_copy_captured"], "yes")
      |> put_in(["visual_density_review", "row_truncation_reviewed"], "true")
      |> put_in(["visual_density_review", "wrapping_reviewed"], 1)
      |> put_in(["visual_density_review", "tap_targets_reviewed"], "yes")
      |> put_in(["visual_density_review", "detail_readability_reviewed"], nil)
      |> put_in(["visual_density_review", "densest_fixture_captured"], "true")

    review = LocalInboxUxEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "Copy review warning_text_captured must be a boolean.")
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "Copy review control_summaries_captured must be a boolean."
             )
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "Copy review state_blocked_claim_copy_captured must be a boolean."
             )
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "Copy review detail_panel_copy_captured must be a boolean.")
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "Visual density review row_truncation_reviewed must be a boolean."
             )
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "Visual density review wrapping_reviewed must be a boolean.")
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "Visual density review tap_targets_reviewed must be a boolean."
             )
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "Visual density review detail_readability_reviewed must be a boolean."
             )
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "Visual density review densest_fixture_captured must be a boolean."
             )
           )
  end

  test "copy and density boolean review fields must be explicit" do
    input =
      complete_json_input()
      |> update_in(["copy_review"], fn review ->
        review
        |> Map.delete("warning_text_captured")
        |> Map.delete("control_summaries_captured")
        |> Map.delete("state_blocked_claim_copy_captured")
      end)
      |> update_in(["visual_density_review"], fn review ->
        review
        |> Map.delete("row_truncation_reviewed")
        |> Map.delete("wrapping_reviewed")
        |> Map.delete("tap_targets_reviewed")
        |> Map.delete("detail_readability_reviewed")
        |> Map.delete("densest_fixture_captured")
      end)

    review = LocalInboxUxEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "Copy review missing warning_text_captured.")
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "Copy review missing control_summaries_captured.")
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "Copy review missing state_blocked_claim_copy_captured.")
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "Visual density review missing row_truncation_reviewed.")
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "Visual density review missing wrapping_reviewed.")
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "Visual density review missing tap_targets_reviewed.")
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "Visual density review missing detail_readability_reviewed.")
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "Visual density review missing densest_fixture_captured.")
           )
  end

  test "state evidence must use supported evidence kinds and include notes" do
    input =
      complete_json_input()
      |> update_in(["state_evidence"], fn [first | rest] ->
        [
          first
          |> Map.put("evidence_kind", "claim_only")
          |> Map.put("notes", "")
          | rest
        ]
      end)

    review = LocalInboxUxEvidenceReview.review(input)

    assert review.status == :open
    assert Enum.any?(review.missing, &String.contains?(&1, "unsupported evidence_kind"))
    assert Enum.any?(review.missing, &String.contains?(&1, "State evidence 1 missing notes"))
  end

  test "operator notes are accepted as state evidence" do
    input =
      complete_json_input()
      |> update_in(["state_evidence"], fn [first | rest] ->
        [Map.put(first, "evidence_kind", "operator_note") | rest]
      end)

    review = LocalInboxUxEvidenceReview.review(input)

    assert review.status == :ready
    assert review.missing == []
  end

  test "interaction evidence must include notes" do
    input =
      complete_json_input()
      |> update_in(["interaction_evidence"], fn [first | rest] ->
        [Map.put(first, "notes", nil) | rest]
      end)

    review = LocalInboxUxEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "Interaction evidence 1 missing notes")
           )
  end

  test "state and interaction evidence must reference declared target devices" do
    input =
      complete_json_input()
      |> update_in(["state_evidence"], fn [first | rest] ->
        [Map.put(first, "target_device_id", "undeclared-device") | rest]
      end)
      |> update_in(["interaction_evidence"], fn [first | rest] ->
        [Map.put(first, "target_device_id", "undeclared-device") | rest]
      end)

    review = LocalInboxUxEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "State evidence 1 references undeclared")
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "Interaction evidence 1 references undeclared")
           )
  end

  test "every declared target device must have UX evidence attached" do
    input =
      complete_json_input()
      |> update_in(["target_devices"], fn devices ->
        devices ++
          [
            %{
              "device_id" => "pixel-8",
              "device_model" => "Pixel 8",
              "os_or_api_version" => "Android API 35",
              "screen_size_class" => "phone",
              "app_build_id" => "meshx-local-debug-2026-05-13",
              "evidence_path" => "artifacts/local-ble/run/ux/pixel-8/"
            }
          ]
      end)

    review = LocalInboxUxEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, ~s(Target device "pixel-8" missing state evidence))
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, ~s(Target device "pixel-8" missing interaction evidence))
           )
  end

  test "every declared target device must cover every UX state and interaction" do
    input =
      complete_json_input()
      |> update_in(["target_devices"], fn devices ->
        devices ++
          [
            %{
              "device_id" => "pixel-8",
              "device_model" => "Pixel 8",
              "os_or_api_version" => "Android API 35",
              "screen_size_class" => "phone",
              "app_build_id" => "meshx-local-debug-2026-05-13",
              "evidence_path" => "artifacts/local-ble/run/ux/pixel-8/"
            }
          ]
      end)
      |> update_in(["state_evidence"], fn evidence ->
        [
          %{
            "state" => "full_message",
            "target_device_id" => "pixel-8",
            "evidence_kind" => "screenshot",
            "artifact_path" => "artifacts/local-ble/run/ux/pixel-8/full-message.png",
            "notes" => "full message row visible on Pixel 8"
          }
          | evidence
        ]
      end)
      |> update_in(["interaction_evidence"], fn evidence ->
        [
          %{
            "interaction" => "filter_change",
            "target_device_id" => "pixel-8",
            "artifact_path" => "artifacts/local-ble/run/ux/pixel-8/filter-change.png",
            "notes" => "filter control usable on Pixel 8"
          }
          | evidence
        ]
      end)

    review = LocalInboxUxEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               ~s(Target device "pixel-8" missing state evidence for: [:unresolved_ref, :gossiped_ref, :stale_ref])
             )
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               ~s(Target device "pixel-8" missing interaction evidence for: [:sort_change, :row_selection, :detail_panel])
             )
           )
  end

  defp complete_json_input do
    %{
      "target_devices" => [
        %{
          "device_id" => "sm-t390",
          "device_model" => "SM-T390",
          "os_or_api_version" => "Android API 28",
          "screen_size_class" => "small_tablet",
          "app_build_id" => "meshx-local-debug-2026-05-13",
          "evidence_path" => "artifacts/local-ble/run/ux/sm-t390/"
        }
      ],
      "state_evidence" =>
        Enum.map(LocalInboxUxEvidenceReview.required_states(), fn state ->
          %{
            "state" => Atom.to_string(state),
            "target_device_id" => "sm-t390",
            "evidence_kind" => "screenshot",
            "artifact_path" => "artifacts/local-ble/run/ux/#{state}.png",
            "notes" => "#{state} row visible"
          }
        end),
      "interaction_evidence" =>
        Enum.map(LocalInboxUxEvidenceReview.required_interactions(), fn interaction ->
          %{
            "interaction" => Atom.to_string(interaction),
            "target_device_id" => "sm-t390",
            "evidence_kind" => "screenshot",
            "artifact_path" => "artifacts/local-ble/run/ux/#{interaction}.png",
            "notes" => "#{interaction} usable"
          }
        end),
      "selected_detail_evidence" =>
        Enum.map(LocalInboxUxEvidenceReview.required_states(), fn state ->
          %{
            "state" => Atom.to_string(state),
            "target_device_id" => "sm-t390",
            "evidence_kind" => "screenshot",
            "artifact_path" => "artifacts/local-ble/run/ux/selected-detail-#{state}.png",
            "limitation_copy" => "#{state} detail is a local BLE observation",
            "next_action_copy" => "#{state} next action is visible",
            "blocked_claim_copy" => "#{state} detail does not claim delivery or trust",
            "notes" => "#{state} selected detail limitation and next-action copy visible"
          }
        end),
      "copy_review" => %{
        "review_path" => "artifacts/local-ble/run/ux/copy-review.md",
        "evidence_kind" => "operator_note",
        "target_device_ids_reviewed" => ["sm-t390"],
        "allowed_wording" => LocalInboxUxEvidenceReview.allowed_wording(),
        "blocked_claims_called_out" =>
          Enum.map(LocalInboxUxEvidenceReview.required_blocked_claims(), &Atom.to_string/1),
        "warning_text_captured" => true,
        "control_summaries_captured" => true,
        "state_blocked_claim_copy_captured" => true,
        "detail_panel_copy_captured" => true
      },
      "visual_density_review" => %{
        "artifact_path" => "artifacts/local-ble/run/ux/density.md",
        "evidence_kind" => "operator_note",
        "densest_fixture_artifact_path" => "artifacts/local-ble/run/ux/densest-fixture.png",
        "densest_fixture_evidence_kind" => "screenshot",
        "target_device_ids_reviewed" => ["sm-t390"],
        "row_truncation_reviewed" => true,
        "wrapping_reviewed" => true,
        "tap_targets_reviewed" => true,
        "detail_readability_reviewed" => true,
        "densest_fixture_captured" => true
      }
    }
  end

  defp add_pixel_8_target_with_evidence(input) do
    input
    |> update_in(["target_devices"], fn devices ->
      devices ++
        [
          %{
            "device_id" => "pixel-8",
            "device_model" => "Pixel 8",
            "os_or_api_version" => "Android API 35",
            "screen_size_class" => "phone",
            "app_build_id" => "meshx-local-debug-2026-05-13",
            "evidence_path" => "artifacts/local-ble/run/ux/pixel-8/"
          }
        ]
    end)
    |> update_in(["state_evidence"], fn evidence ->
      evidence ++ target_state_evidence("pixel-8")
    end)
    |> update_in(["interaction_evidence"], fn evidence ->
      evidence ++ target_interaction_evidence("pixel-8")
    end)
    |> update_in(["selected_detail_evidence"], fn evidence ->
      evidence ++ target_selected_detail_evidence("pixel-8")
    end)
    |> update_in(["visual_density_review", "target_device_ids_reviewed"], &["pixel-8" | &1])
  end

  defp target_state_evidence(target_device_id) do
    Enum.map(LocalInboxUxEvidenceReview.required_states(), fn state ->
      %{
        "state" => Atom.to_string(state),
        "target_device_id" => target_device_id,
        "evidence_kind" => "screenshot",
        "artifact_path" => "artifacts/local-ble/run/ux/#{target_device_id}/#{state}.png",
        "notes" => "#{state} row visible on #{target_device_id}"
      }
    end)
  end

  defp target_interaction_evidence(target_device_id) do
    Enum.map(LocalInboxUxEvidenceReview.required_interactions(), fn interaction ->
      %{
        "interaction" => Atom.to_string(interaction),
        "target_device_id" => target_device_id,
        "evidence_kind" => "screenshot",
        "artifact_path" => "artifacts/local-ble/run/ux/#{target_device_id}/#{interaction}.png",
        "notes" => "#{interaction} usable on #{target_device_id}"
      }
    end)
  end

  defp target_selected_detail_evidence(target_device_id) do
    Enum.map(LocalInboxUxEvidenceReview.required_states(), fn state ->
      %{
        "state" => Atom.to_string(state),
        "target_device_id" => target_device_id,
        "evidence_kind" => "screenshot",
        "artifact_path" =>
          "artifacts/local-ble/run/ux/#{target_device_id}/selected-detail-#{state}.png",
        "limitation_copy" => "#{state} detail is a local BLE observation on #{target_device_id}",
        "next_action_copy" => "#{state} next action is visible on #{target_device_id}",
        "blocked_claim_copy" => "#{state} detail does not claim delivery or trust",
        "notes" => "#{state} selected detail copy visible on #{target_device_id}"
      }
    end)
  end
end
