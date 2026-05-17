defmodule Mix.Tasks.MeshxMobileLocalReleaseCandidateReviewTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mix.Tasks.Meshx.Mobile.LocalRelease.CandidateReview
  alias MeshxMobileApp.BLE.LocalReleaseCandidateEvidenceReview

  setup do
    Mix.Task.reenable("meshx.mobile.local_release.candidate_review")
    File.rm_rf!("tmp/local-release-candidate-review-test")
    :ok
  end

  test "prints an open review summary without input" do
    output =
      capture_io(fn ->
        CandidateReview.run([])
      end)

    assert output =~ "LOCAL_RELEASE_CANDIDATE_REVIEW status=open complete=false"
    assert output =~ "RELEASE_CANDIDATE_REVIEW missing"
    assert output =~ "open_hardware_gates 4"

    assert output =~
             "OPERATOR_NOTE_PATHS readiness=false completion_audit=false completion_audit_plain_text=false focused_remaining_items_audit=false focused_remaining_items_plain_text=false direct_full_mx_aux_checklist=false upstream_patch_handoff=false blocker_matrix=false release_manifest=false recent_evidence=false persistence_lifecycle=false lifecycle_review=false ios_parity_review=false full_resolution_review=false known_good_transport_review=false multi_hop_review=false routing_review=false security_review=false ux_review=false"

    assert output =~ "PERSISTENCE_LIFECYCLE default="
    assert output =~ "blocked_gates=0/0"
    assert output =~ "LIFECYCLE_REVIEW status="
    assert output =~ "background=false"
    assert output =~ "IOS_PARITY_REVIEW status="
    assert output =~ "parity=false"
    assert output =~ "FULL_RESOLUTION_REVIEW status="
    assert output =~ "resolved=false"
    assert output =~ "KNOWN_GOOD_TRANSPORT_REVIEW status="
    assert output =~ "transport=false"
    assert output =~ "MULTI_HOP_REVIEW status="
    assert output =~ "physical=false"
    assert output =~ "SECURITY_REVIEW status="
    assert output =~ "trusted=false"
    assert output =~ "ROUTING_REVIEW status="
    assert output =~ "routed=false"
    assert output =~ "UX_REVIEW status="
    assert output =~ "targets=0"
    assert output =~ "all_selected_details=false"

    assert output =~
             "RELEASE_CANDIDATE_TEMPLATE command=mix meshx.mobile.local_release.candidate_review --template"
  end

  test "prints operator note path linkage for complete non-JSON input" do
    input_path = "tmp/local-release-candidate-review-test/input.json"
    File.mkdir_p!(Path.dirname(input_path))
    File.write!(input_path, JSON.encode!(complete_json_input()) <> "\n")

    output =
      capture_io(fn ->
        CandidateReview.run(["--input", input_path])
      end)

    assert output =~ "LOCAL_RELEASE_CANDIDATE_REVIEW status=ready complete=true"

    assert output =~
             "OPERATOR_NOTE_PATHS readiness=true completion_audit=true completion_audit_plain_text=true focused_remaining_items_audit=true focused_remaining_items_plain_text=true direct_full_mx_aux_checklist=true upstream_patch_handoff=true blocker_matrix=true release_manifest=true recent_evidence=true persistence_lifecycle=true lifecycle_review=true ios_parity_review=true full_resolution_review=true known_good_transport_review=true multi_hop_review=true routing_review=true security_review=true ux_review=true"

    assert output =~ "PERSISTENCE_LIFECYCLE default=memory_only"
    assert output =~ "opt_in=true"
    assert output =~ "blocked_gates=6/6"
    assert output =~ "LIFECYCLE_REVIEW status=ready"
    assert output =~ "background=false"
    assert output =~ "IOS_PARITY_REVIEW status=ready"
    assert output =~ "parity=false"
    assert output =~ "FULL_RESOLUTION_REVIEW status=ready"
    assert output =~ "resolved=false"
    assert output =~ "KNOWN_GOOD_TRANSPORT_REVIEW status=ready"
    assert output =~ "transport=false"
    assert output =~ "MULTI_HOP_REVIEW status=ready"
    assert output =~ "physical=false"
    assert output =~ "SECURITY_REVIEW status=ready"
    assert output =~ "complete=true"
    assert output =~ "ROUTING_REVIEW status=ready"
    assert output =~ "routed=false"
    assert output =~ "UX_REVIEW status=ready"
    assert output =~ "targets=1"
    assert output =~ "all_selected_details=true"

    refute output =~ "RELEASE_CANDIDATE_TEMPLATE"
  end

  test "prints machine-readable JSON for missing evidence" do
    output =
      capture_io(fn ->
        CandidateReview.run(["--json"])
      end)

    assert {:ok, decoded} = JSON.decode(output)
    assert decoded["review_version"] == 1
    assert decoded["boundary"] == "advert_only_local_release_candidate_evidence"
    assert decoded["status"] == "open"
    assert decoded["release_candidate_evidence_complete?"] == false
  end

  test "reviews string-keyed JSON input and writes output artifact" do
    input_path = "tmp/local-release-candidate-review-test/input.json"
    output_path = "tmp/local-release-candidate-review-test/review.json"
    File.mkdir_p!(Path.dirname(input_path))
    File.write!(input_path, JSON.encode!(complete_json_input()) <> "\n")

    output =
      capture_io(fn ->
        CandidateReview.run(["--input", input_path, "--json", "--out", output_path])
      end)

    assert {:ok, decoded_output} = JSON.decode(output)
    assert decoded_output["status"] == "ready"
    assert decoded_output["release_candidate_evidence_complete?"] == true
    assert File.exists?(output_path)
    assert {:ok, decoded_file} = output_path |> File.read!() |> JSON.decode()
    assert decoded_file["missing"] == []
  end

  test "prints and writes an incomplete operator evidence template" do
    output_path = "tmp/local-release-candidate-review-test/template.json"

    output =
      capture_io(fn ->
        CandidateReview.run(["--template", "--out", output_path])
      end)

    assert {:ok, decoded_output} = JSON.decode(output)
    assert File.exists?(output_path)
    assert {:ok, decoded_file} = output_path |> File.read!() |> JSON.decode()
    assert decoded_file == decoded_output

    assert decoded_output["operator_notes"]["allowed_wording"] ==
             LocalReleaseCandidateEvidenceReview.allowed_wording()

    review = LocalReleaseCandidateEvidenceReview.review(decoded_output)
    assert review.status == :open
    refute review.release_candidate_evidence_complete?
    refute review.whole_project_complete?
  end

  test "rejects unknown options and missing paths" do
    assert_raise Mix.Error, ~r/unknown option/, fn ->
      capture_io(fn -> CandidateReview.run(["--bad"]) end)
    end

    assert_raise Mix.Error, ~r/missing path for --input/, fn ->
      capture_io(fn -> CandidateReview.run(["--input"]) end)
    end

    assert_raise Mix.Error, ~r/missing path for --out/, fn ->
      capture_io(fn -> CandidateReview.run(["--out"]) end)
    end

    assert_raise Mix.Error, ~r/--template cannot be combined with --input/, fn ->
      capture_io(fn -> CandidateReview.run(["--template", "--input", "tmp/input.json"]) end)
    end
  end

  defp complete_json_input do
    %{
      "readiness_manifest_path" => "tmp/local-readiness.json",
      "release_manifest_path" => "tmp/local-release.json",
      "recent_evidence_inventory_path" => "tmp/local-release-recent-evidence.json",
      "completion_audit_path" => "tmp/local-completion-audit.json",
      "completion_audit_plain_text_path" => "tmp/local-completion-audit.txt",
      "focused_remaining_items_audit_path" => "tmp/focused-remaining-items-audit.json",
      "focused_remaining_items_plain_text_path" => "tmp/focused-remaining-items-audit.txt",
      "direct_full_mx_aux_validation_checklist_path" => "tmp/aux-validation-checklist.md",
      "upstream_patch_maintainer_handoff_path" => "tmp/upstream-maintainer-handoff.md",
      "completion_blocker_matrix_path" => "tmp/local-completion-blocker-matrix.json",
      "advert_gossip_audit_path" => "tmp/advert-gossip-audit.txt",
      "persistence_lifecycle_plan_path" => "tmp/local-persistence-lifecycle-plan.json",
      "persistence_lifecycle" => %{
        "plan_path" => "tmp/local-persistence-lifecycle-plan.json",
        "plan_version" => 1,
        "boundary" => "production_default_local_inbox_persistence_plan",
        "current_default_mode" => "memory_only",
        "opt_in_durable_snapshots_available?" => true,
        "production_default_persistence_allowed?" => false,
        "default_lifecycle_claim_allowed?" => false,
        "gate_count" => 6,
        "blocked_gate_count" => 6
      },
      "lifecycle_review_path" => "tmp/local-lifecycle-hardware-review.json",
      "lifecycle_review" => %{
        "review_path" => "tmp/local-lifecycle-hardware-review.json",
        "review_version" => 1,
        "boundary" => "mobile_ble_lifecycle_hardware_evidence_review",
        "status" => "ready",
        "lifecycle_hardware_evidence_complete?" => true,
        "android_foreground_service_claim_allowed?" => false,
        "android_background_ble_claim_allowed?" => false,
        "ios_background_claim_allowed?" => false,
        "background_ble_claim_allowed?" => false,
        "restart_claim_allowed?" => false,
        "scheduled_retry_claim_allowed?" => false,
        "background_gossip_claim_allowed?" => false,
        "delivery_claim_allowed?" => false
      },
      "ios_parity_review_path" => "tmp/local-ios-parity-hardware-review.json",
      "ios_parity_review" => %{
        "review_path" => "tmp/local-ios-parity-hardware-review.json",
        "review_version" => 1,
        "boundary" => "ios_advert_only_hardware_evidence_review",
        "status" => "ready",
        "ios_hardware_evidence_complete?" => true,
        "ios_participation_claim_allowed?" => false,
        "ios_hardware_claim_allowed?" => false,
        "ios_legacy_beacon_observe_claim_allowed?" => false,
        "ios_legacy_beacon_gossip_claim_allowed?" => false,
        "ios_full_envelope_advert_claim_allowed?" => false,
        "ios_background_ble_claim_allowed?" => false,
        "ios_parity_claim_allowed?" => false
      },
      "full_resolution_review_path" => "tmp/local-full-resolution-transport-review.json",
      "full_resolution_review" => %{
        "review_path" => "tmp/local-full-resolution-transport-review.json",
        "review_version" => 1,
        "boundary" => "full_message_resolution_transport_evidence_review",
        "status" => "ready",
        "full_resolution_transport_evidence_complete?" => true,
        "real_fetch_transport_validated?" => false,
        "full_message_resolution_claim_allowed?" => false,
        "known_good_transport_claim_allowed?" => false,
        "gatt_fetch_success_claim_allowed?" => false,
        "message_delivery_claim_allowed?" => false,
        "trusted_message_claim_allowed?" => false
      },
      "known_good_transport_review_path" => "tmp/local-known-good-transport-review.json",
      "known_good_transport_review" => %{
        "review_path" => "tmp/local-known-good-transport-review.json",
        "review_version" => 1,
        "boundary" => "known_good_transport_evidence_review",
        "status" => "ready",
        "known_good_transport_evidence_complete?" => true,
        "known_good_transport_claim_allowed?" => false,
        "gatt_fetch_success_claim_allowed?" => false,
        "full_message_resolution_claim_allowed?" => false,
        "message_delivery_claim_allowed?" => false
      },
      "multi_hop_review_path" => "tmp/local-multi-hop-hardware-review.json",
      "multi_hop_review" => %{
        "review_path" => "tmp/local-multi-hop-hardware-review.json",
        "review_version" => 1,
        "boundary" => "multi_hop_hardware_evidence_review",
        "status" => "ready",
        "multi_hop_hardware_evidence_complete?" => true,
        "multi_hop_physical_proof_present?" => false,
        "multi_hop_hardware_gossip_claim_allowed?" => false,
        "routed_delivery_claim_allowed?" => false,
        "guaranteed_delivery_claim_allowed?" => false,
        "trusted_delivery_claim_allowed?" => false,
        "background_operation_claim_allowed?" => false
      },
      "security_review_path" => "tmp/local-security-release-review.json",
      "security_review" => %{
        "review_path" => "tmp/local-security-release-review.json",
        "review_version" => 1,
        "boundary" => "local_security_release_evidence_review",
        "status" => "ready",
        "security_release_evidence_complete?" => true,
        "authenticated_peer_identity_claim_allowed?" => false,
        "authenticated_message_claim_allowed?" => false,
        "trusted_message_claim_allowed?" => false,
        "trusted_delivery_claim_allowed?" => false
      },
      "routing_review_path" => "tmp/local-routing-production-review.json",
      "routing_review" => %{
        "review_path" => "tmp/local-routing-production-review.json",
        "review_version" => 1,
        "boundary" => "production_routing_evidence_review",
        "status" => "ready",
        "production_routing_evidence_complete?" => true,
        "route_table_claim_allowed?" => false,
        "route_selection_claim_allowed?" => false,
        "forwarding_claim_allowed?" => false,
        "routed_delivery_claim_allowed?" => false,
        "guaranteed_delivery_claim_allowed?" => false,
        "multi_hop_hardware_claim_allowed?" => false
      },
      "ux_review_path" => "tmp/local-inbox-ux-review.json",
      "ux_review" => %{
        "review_path" => "tmp/local-inbox-ux-review.json",
        "review_version" => 1,
        "boundary" => "nearby_messages_on_device_ux_evidence",
        "status" => "ready",
        "on_device_ux_evidence_complete?" => true,
        "production_ux_claim_allowed?" => false,
        "delivery_claim_allowed?" => false,
        "trusted_delivery_claim_allowed?" => false,
        "routing_claim_allowed?" => false,
        "target_device_count" => 1,
        "all_target_devices_have_state_coverage?" => true,
        "all_target_devices_have_interaction_coverage?" => true,
        "all_target_devices_have_selected_detail_coverage?" => true,
        "all_target_devices_have_selected_detail_copy_anchors?" => true,
        "all_target_devices_copy_reviewed?" => true,
        "all_target_devices_density_reviewed?" => true
      },
      "hardware_attachments" => [
        %{
          "device_model" => "SM-T577U",
          "os_or_api_version" => "Android API 30",
          "role" => "sender",
          "command_or_harness" => "scripts/android_ble_message_delivery_two_device.sh",
          "summary_path" => "artifacts/meshx-android-m59-gossip-live/summary.json",
          "raw_log_path" => "artifacts/meshx-android-m59-gossip-live/sender.logcat",
          "gate_ids" => ["android_legacy_beacon_gossip_one_hop"],
          "evidence_types_by_gate" => %{
            "android_legacy_beacon_gossip_one_hop" => "android_legacy_beacon_gossip_summary"
          }
        }
      ],
      "operator_notes" => %{
        "notes_path" => "docs/local_ble_release_artifact_bundle.md",
        "allowed_wording" => LocalReleaseCandidateEvidenceReview.allowed_wording(),
        "blocked_claims_called_out" =>
          Enum.map(
            LocalReleaseCandidateEvidenceReview.required_blocked_claims(),
            &Atom.to_string/1
          ),
        "open_hardware_gate_ids_called_out" => [
          "android_full_envelope_advert_pair",
          "gatt_known_good_fetch",
          "advert_gossip_multi_hop_hardware",
          "ios_advert_only_participation"
        ],
        "readiness_manifest_path" => "tmp/local-readiness.json",
        "completion_audit_path" => "tmp/local-completion-audit.json",
        "completion_audit_plain_text_path" => "tmp/local-completion-audit.txt",
        "focused_remaining_items_audit_path" => "tmp/focused-remaining-items-audit.json",
        "focused_remaining_items_plain_text_path" => "tmp/focused-remaining-items-audit.txt",
        "direct_full_mx_aux_validation_checklist_path" => "tmp/aux-validation-checklist.md",
        "upstream_patch_maintainer_handoff_path" => "tmp/upstream-maintainer-handoff.md",
        "completion_blocker_matrix_path" => "tmp/local-completion-blocker-matrix.json",
        "release_manifest_path" => "tmp/local-release.json",
        "recent_evidence_inventory_path" => "tmp/local-release-recent-evidence.json",
        "persistence_lifecycle_plan_path" => "tmp/local-persistence-lifecycle-plan.json",
        "lifecycle_review_path" => "tmp/local-lifecycle-hardware-review.json",
        "ios_parity_review_path" => "tmp/local-ios-parity-hardware-review.json",
        "full_resolution_review_path" => "tmp/local-full-resolution-transport-review.json",
        "known_good_transport_review_path" => "tmp/local-known-good-transport-review.json",
        "multi_hop_review_path" => "tmp/local-multi-hop-hardware-review.json",
        "routing_review_path" => "tmp/local-routing-production-review.json",
        "security_review_path" => "tmp/local-security-release-review.json",
        "ux_review_path" => "tmp/local-inbox-ux-review.json"
      }
    }
  end
end
