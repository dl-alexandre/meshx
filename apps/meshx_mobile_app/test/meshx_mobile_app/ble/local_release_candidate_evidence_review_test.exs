defmodule MeshxMobileApp.BLE.LocalReleaseCandidateEvidenceReviewTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.LocalReleaseCandidateEvidenceReview

  test "review is ready when operator evidence has required manifests, hardware metadata, and wording gates" do
    review = LocalReleaseCandidateEvidenceReview.review(complete_input())

    assert review.status == :ready
    assert review.release_candidate_evidence_complete?
    refute review.whole_project_complete?
    assert review.boundary == :advert_only_local_release_candidate_evidence
    assert review.missing == []
    assert review.persistence_lifecycle.plan_version == 1

    assert review.persistence_lifecycle.boundary ==
             :production_default_local_inbox_persistence_plan

    assert review.persistence_lifecycle.current_default_mode == :memory_only
    assert review.persistence_lifecycle.opt_in_durable_snapshots_available?
    refute review.persistence_lifecycle.production_default_persistence_allowed?
    refute review.persistence_lifecycle.default_lifecycle_claim_allowed?
    assert review.persistence_lifecycle.gate_count == 6
    assert review.persistence_lifecycle.blocked_gate_count == 6
    assert review.lifecycle_review.review_version == 1
    assert review.lifecycle_review.boundary == :mobile_ble_lifecycle_hardware_evidence_review
    assert review.lifecycle_review.status == :ready
    assert review.lifecycle_review.lifecycle_hardware_evidence_complete?
    refute review.lifecycle_review.android_foreground_service_claim_allowed?
    refute review.lifecycle_review.android_background_ble_claim_allowed?
    refute review.lifecycle_review.ios_background_claim_allowed?
    refute review.lifecycle_review.background_ble_claim_allowed?
    refute review.lifecycle_review.restart_claim_allowed?
    refute review.lifecycle_review.scheduled_retry_claim_allowed?
    refute review.lifecycle_review.background_gossip_claim_allowed?
    refute review.lifecycle_review.delivery_claim_allowed?
    assert review.ios_parity_review.review_version == 1
    assert review.ios_parity_review.boundary == :ios_advert_only_hardware_evidence_review
    assert review.ios_parity_review.status == :ready
    assert review.ios_parity_review.ios_hardware_evidence_complete?
    refute review.ios_parity_review.ios_participation_claim_allowed?
    refute review.ios_parity_review.ios_hardware_claim_allowed?
    refute review.ios_parity_review.ios_legacy_beacon_observe_claim_allowed?
    refute review.ios_parity_review.ios_legacy_beacon_gossip_claim_allowed?
    refute review.ios_parity_review.ios_full_envelope_advert_claim_allowed?
    refute review.ios_parity_review.ios_background_ble_claim_allowed?
    refute review.ios_parity_review.ios_parity_claim_allowed?
    assert review.full_resolution_review.review_version == 1

    assert review.full_resolution_review.boundary ==
             :full_message_resolution_transport_evidence_review

    assert review.full_resolution_review.status == :ready
    assert review.full_resolution_review.full_resolution_transport_evidence_complete?
    refute review.full_resolution_review.real_fetch_transport_validated?
    refute review.full_resolution_review.full_message_resolution_claim_allowed?
    refute review.full_resolution_review.known_good_transport_claim_allowed?
    refute review.full_resolution_review.gatt_fetch_success_claim_allowed?
    refute review.full_resolution_review.message_delivery_claim_allowed?
    refute review.full_resolution_review.trusted_message_claim_allowed?
    assert review.known_good_transport_review.review_version == 1
    assert review.known_good_transport_review.boundary == :known_good_transport_evidence_review
    assert review.known_good_transport_review.status == :ready
    assert review.known_good_transport_review.known_good_transport_evidence_complete?
    refute review.known_good_transport_review.known_good_transport_claim_allowed?
    refute review.known_good_transport_review.gatt_fetch_success_claim_allowed?
    refute review.known_good_transport_review.full_message_resolution_claim_allowed?
    refute review.known_good_transport_review.message_delivery_claim_allowed?
    assert review.multi_hop_review.review_version == 1
    assert review.multi_hop_review.boundary == :multi_hop_hardware_evidence_review
    assert review.multi_hop_review.status == :ready
    assert review.multi_hop_review.multi_hop_hardware_evidence_complete?
    refute review.multi_hop_review.multi_hop_physical_proof_present?
    refute review.multi_hop_review.multi_hop_hardware_gossip_claim_allowed?
    refute review.multi_hop_review.routed_delivery_claim_allowed?
    refute review.multi_hop_review.guaranteed_delivery_claim_allowed?
    refute review.multi_hop_review.trusted_delivery_claim_allowed?
    refute review.multi_hop_review.background_operation_claim_allowed?
    assert review.security_review.review_version == 1
    assert review.security_review.boundary == :local_security_release_evidence_review
    assert review.security_review.status == :ready
    assert review.security_review.security_release_evidence_complete?
    refute review.security_review.authenticated_peer_identity_claim_allowed?
    refute review.security_review.authenticated_message_claim_allowed?
    refute review.security_review.trusted_message_claim_allowed?
    refute review.security_review.trusted_delivery_claim_allowed?
    assert review.routing_review.review_version == 1
    assert review.routing_review.boundary == :production_routing_evidence_review
    assert review.routing_review.status == :ready
    assert review.routing_review.production_routing_evidence_complete?
    refute review.routing_review.route_table_claim_allowed?
    refute review.routing_review.route_selection_claim_allowed?
    refute review.routing_review.forwarding_claim_allowed?
    refute review.routing_review.routed_delivery_claim_allowed?
    refute review.routing_review.guaranteed_delivery_claim_allowed?
    refute review.routing_review.multi_hop_hardware_claim_allowed?
    assert review.ux_review.review_version == 1
    assert review.ux_review.boundary == :nearby_messages_on_device_ux_evidence
    assert review.ux_review.status == :ready
    assert review.ux_review.on_device_ux_evidence_complete?
    refute review.ux_review.production_ux_claim_allowed?
    refute review.ux_review.delivery_claim_allowed?
    refute review.ux_review.trusted_delivery_claim_allowed?
    refute review.ux_review.routing_claim_allowed?
    assert review.ux_review.target_device_count == 1
    assert review.ux_review.all_target_devices_have_state_coverage?
    assert review.ux_review.all_target_devices_have_interaction_coverage?
    assert review.ux_review.all_target_devices_have_selected_detail_coverage?
    assert review.ux_review.all_target_devices_have_selected_detail_copy_anchors?
    assert review.ux_review.all_target_devices_copy_reviewed?
    assert review.ux_review.all_target_devices_density_reviewed?

    assert review.open_hardware_gate_ids == [
             :android_full_envelope_advert_pair,
             :gatt_known_good_fetch,
             :advert_gossip_multi_hop_hardware,
             :ios_advert_only_participation
           ]

    assert LocalReleaseCandidateEvidenceReview.required_gate_evidence_types()
           |> Map.fetch!(:android_legacy_beacon_gossip_one_hop) ==
             :android_legacy_beacon_gossip_summary
  end

  test "review stays open when generated paths and operator attachments are missing" do
    review = LocalReleaseCandidateEvidenceReview.review(%{})

    assert review.status == :open
    refute review.release_candidate_evidence_complete?

    assert "Missing readiness_manifest_path." in review.missing
    assert "Missing completion_audit_path." in review.missing
    assert "Missing completion_audit_plain_text_path." in review.missing
    assert "Missing release_manifest_path." in review.missing
    assert "Missing completion_blocker_matrix_path." in review.missing
    assert "Missing recent_evidence_inventory_path." in review.missing
    assert "Missing advert_gossip_audit_path." in review.missing
    assert "Missing persistence_lifecycle_plan_path." in review.missing
    assert "Missing persistence_lifecycle summary." in review.missing
    assert "Persistence lifecycle missing plan_path." in review.missing
    assert "Missing lifecycle_review_path." in review.missing
    assert "Missing lifecycle_review summary." in review.missing
    assert "Lifecycle review missing review_path." in review.missing
    assert "Missing ios_parity_review_path." in review.missing
    assert "Missing ios_parity_review summary." in review.missing
    assert "iOS parity review missing review_path." in review.missing
    assert "Missing full_resolution_review_path." in review.missing
    assert "Missing full_resolution_review summary." in review.missing
    assert "Full-resolution review missing review_path." in review.missing
    assert "Missing known_good_transport_review_path." in review.missing
    assert "Missing known_good_transport_review summary." in review.missing
    assert "Known-good transport review missing review_path." in review.missing
    assert "Missing multi_hop_review_path." in review.missing
    assert "Missing multi_hop_review summary." in review.missing
    assert "Multi-hop review missing review_path." in review.missing
    assert "Missing routing_review_path." in review.missing
    assert "Missing routing_review summary." in review.missing
    assert "Routing review missing review_path." in review.missing
    assert "Missing security_review_path." in review.missing
    assert "Missing security_review summary." in review.missing
    assert "Security review missing review_path." in review.missing
    assert "Missing ux_review_path." in review.missing
    assert "Missing ux_review summary." in review.missing
    assert "UX review missing review_path." in review.missing
    assert "UX review status must be ready." in review.missing
    assert "Missing at least one hardware attachment." in review.missing
    assert "Operator notes missing notes_path." in review.missing
    assert "Operator notes missing completion_audit_path." in review.missing
    assert "Operator notes missing completion_audit_plain_text_path." in review.missing
    assert "Operator notes missing completion_blocker_matrix_path." in review.missing
    assert "Operator notes missing recent_evidence_inventory_path." in review.missing
    assert "Operator notes missing persistence_lifecycle_plan_path." in review.missing
    assert "Operator notes missing lifecycle_review_path." in review.missing
    assert "Operator notes missing ios_parity_review_path." in review.missing
    assert "Operator notes missing full_resolution_review_path." in review.missing
    assert "Operator notes missing known_good_transport_review_path." in review.missing
    assert "Operator notes missing multi_hop_review_path." in review.missing
    assert "Operator notes missing routing_review_path." in review.missing
    assert "Operator notes missing security_review_path." in review.missing
    assert "Operator notes missing ux_review_path." in review.missing

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "Operator notes missing blocked claim callouts")
           )
  end

  test "hardware attachments must include device metadata, command, summary, log, and gate ids" do
    input =
      complete_input()
      |> Map.put(:hardware_attachments, [
        %{
          device_model: " ",
          os_or_api_version: nil,
          role: "observer",
          command_or_harness: "",
          summary_path: nil,
          raw_log_path: "/tmp/logcat.txt",
          gate_ids: [],
          evidence_types_by_gate: %{}
        }
      ])

    review = LocalReleaseCandidateEvidenceReview.review(input)

    assert "Hardware attachment 1 missing device_model." in review.missing
    assert "Hardware attachment 1 missing os_or_api_version." in review.missing
    assert "Hardware attachment 1 missing command_or_harness." in review.missing
    assert "Hardware attachment 1 missing summary_path." in review.missing
    assert "Hardware attachment 1 missing gate_ids." in review.missing
  end

  test "hardware attachment containers must be explicit valid shapes" do
    input =
      complete_input()
      |> Map.put(:hardware_attachments, [
        %{
          device_model: "SM-T577U",
          os_or_api_version: "Android API 30",
          role: "sender",
          command_or_harness: "scripts/android_ble_message_delivery_two_device.sh",
          summary_path: "/tmp/summary.json",
          raw_log_path: "/tmp/sender.logcat",
          gate_ids: "android_legacy_beacon_gossip_one_hop",
          evidence_types_by_gate: ["not", "an", "object"]
        }
      ])

    review = LocalReleaseCandidateEvidenceReview.review(input)

    assert review.status == :open
    assert "Hardware attachment 1 gate_ids must be a list." in review.missing
    assert "Hardware attachment 1 evidence_types_by_gate must be an object." in review.missing
  end

  test "top-level hardware attachments must be a list" do
    input =
      complete_input()
      |> Map.put(:hardware_attachments, %{device_model: "SM-T577U"})

    review = LocalReleaseCandidateEvidenceReview.review(input)

    assert review.status == :open
    assert "hardware_attachments must be a list." in review.missing
    assert "Missing at least one hardware attachment." in review.missing
  end

  test "hardware attachment gate evidence types must match release hardware gates" do
    input =
      complete_input()
      |> Map.put(:hardware_attachments, [
        %{
          device_model: "SM-T577U",
          os_or_api_version: "Android API 30",
          role: "sender",
          command_or_harness: "scripts/android_ble_message_delivery_two_device.sh",
          summary_path: "/tmp/summary.json",
          raw_log_path: "/tmp/sender.logcat",
          gate_ids: [
            :android_legacy_beacon_gossip_one_hop,
            :gatt_known_good_fetch
          ],
          evidence_types_by_gate: %{
            android_legacy_beacon_gossip_one_hop: :generic_log,
            gatt_known_good_fetch: :standalone_gatt_interop_log
          }
        }
      ])

    review = LocalReleaseCandidateEvidenceReview.review(input)

    assert "Hardware attachment 1 gate android_legacy_beacon_gossip_one_hop evidence_type must be android_legacy_beacon_gossip_summary, got :generic_log." in review.missing
  end

  test "hardware attachment gate evidence types are required for every cited gate" do
    input =
      complete_input()
      |> put_in([:hardware_attachments, Access.at(0), :evidence_types_by_gate], %{})

    review = LocalReleaseCandidateEvidenceReview.review(input)

    assert "Hardware attachment 1 gate android_legacy_beacon_gossip_one_hop missing evidence_type android_legacy_beacon_gossip_summary." in review.missing
  end

  test "release candidate artifact paths must be archive-relative" do
    input =
      complete_input()
      |> Map.put(:readiness_manifest_path, "/tmp/local-readiness.json")
      |> Map.put(:completion_audit_path, "../outside/local-completion-audit.json")
      |> Map.put(:completion_audit_plain_text_path, "../outside/local-completion-audit.txt")
      |> Map.put(:release_manifest_path, "https://example.invalid/local-release.json")
      |> Map.put(:recent_evidence_inventory_path, "/tmp/local-release-recent-evidence.json")
      |> put_in([:hardware_attachments, Access.at(0), :summary_path], "file:///tmp/summary.json")
      |> put_in([:hardware_attachments, Access.at(0), :raw_log_path], "/tmp/sender.logcat")
      |> put_in([:operator_notes, :notes_path], "~/release-notes.md")

    review = LocalReleaseCandidateEvidenceReview.review(input)

    assert review.status == :open
    assert "readiness_manifest_path must be a relative artifact path." in review.missing
    assert "completion_audit_path must be a relative artifact path." in review.missing
    assert "completion_audit_plain_text_path must be a relative artifact path." in review.missing
    assert "release_manifest_path must be a relative artifact path." in review.missing
    assert "recent_evidence_inventory_path must be a relative artifact path." in review.missing

    assert "Hardware attachment 1 summary_path must be a relative artifact path." in review.missing

    assert "Hardware attachment 1 raw_log_path must be a relative artifact path." in review.missing
    assert "Operator notes notes_path must be a relative artifact path." in review.missing
  end

  test "release candidate artifact paths must be strings and not need trimming" do
    input =
      complete_input()
      |> Map.put(:readiness_manifest_path, 123)
      |> Map.put(:completion_audit_path, " tmp/local-completion-audit.json")
      |> Map.put(:completion_audit_plain_text_path, " tmp/local-completion-audit.txt")
      |> put_in([:hardware_attachments, Access.at(0), :summary_path], 456)
      |> put_in([:hardware_attachments, Access.at(0), :raw_log_path], " tmp/sender.logcat")
      |> put_in([:operator_notes, :notes_path], 789)
      |> put_in([:operator_notes, :completion_audit_path], " tmp/local-completion-audit.json")
      |> put_in(
        [:operator_notes, :completion_audit_plain_text_path],
        " tmp/local-completion-audit.txt"
      )

    review = LocalReleaseCandidateEvidenceReview.review(input)

    assert review.status == :open
    assert "readiness_manifest_path must be a string." in review.missing

    assert "completion_audit_path must not have leading or trailing whitespace." in review.missing
    assert "completion_audit_plain_text_path must not have leading or trailing whitespace." in review.missing

    assert "Hardware attachment 1 summary_path must be a string." in review.missing

    assert "Hardware attachment 1 raw_log_path must not have leading or trailing whitespace." in review.missing

    assert "Operator notes notes_path must be a string." in review.missing

    assert "Operator notes completion_audit_path must not have leading or trailing whitespace." in review.missing

    assert "Operator notes completion_audit_plain_text_path must not have leading or trailing whitespace." in review.missing
  end

  test "operator notes must use approved wording and call out every blocked claim and open gate" do
    input =
      complete_input()
      |> put_in([:operator_notes, :allowed_wording], "MeshX delivers nearby messages.")
      |> put_in([:operator_notes, :blocked_claims_called_out], [:guaranteed_delivery])
      |> put_in([:operator_notes, :open_hardware_gate_ids_called_out], [:gatt_known_good_fetch])

    review = LocalReleaseCandidateEvidenceReview.review(input)

    assert "Operator notes must use the approved messages-seen-nearby wording." in review.missing

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "Operator notes missing blocked claim callouts")
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "Operator notes missing open hardware gate callouts")
           )
  end

  test "operator notes containers must be explicit valid shapes" do
    input =
      complete_input()
      |> put_in([:operator_notes, :blocked_claims_called_out], "message_delivery")
      |> put_in([:operator_notes, :open_hardware_gate_ids_called_out], "gatt_known_good_fetch")

    review = LocalReleaseCandidateEvidenceReview.review(input)

    assert review.status == :open
    assert "Operator notes blocked_claims_called_out must be a list." in review.missing
    assert "Operator notes open_hardware_gate_ids_called_out must be a list." in review.missing
  end

  test "operator notes must be an object" do
    input =
      complete_input()
      |> Map.put(:operator_notes, "not-an-object")

    review = LocalReleaseCandidateEvidenceReview.review(input)

    assert review.status == :open
    assert "operator_notes must be an object." in review.missing
    assert "Operator notes missing notes_path." in review.missing
  end

  test "operator note artifact paths must match top-level release candidate paths" do
    input =
      complete_input()
      |> put_in([:operator_notes, :readiness_manifest_path], "tmp/stale-readiness.json")
      |> put_in([:operator_notes, :completion_audit_path], "tmp/stale-completion-audit.json")
      |> put_in(
        [:operator_notes, :completion_audit_plain_text_path],
        "tmp/stale-completion-audit.txt"
      )
      |> put_in(
        [:operator_notes, :completion_blocker_matrix_path],
        "tmp/stale-completion-blocker-matrix.json"
      )
      |> put_in([:operator_notes, :release_manifest_path], "tmp/stale-release.json")
      |> put_in(
        [:operator_notes, :recent_evidence_inventory_path],
        "tmp/stale-local-release-recent-evidence.json"
      )
      |> put_in(
        [:operator_notes, :persistence_lifecycle_plan_path],
        "tmp/stale-persistence-lifecycle-plan.json"
      )
      |> put_in([:operator_notes, :lifecycle_review_path], "tmp/stale-lifecycle-review.json")
      |> put_in([:operator_notes, :ios_parity_review_path], "tmp/stale-ios-parity-review.json")
      |> put_in(
        [:operator_notes, :full_resolution_review_path],
        "tmp/stale-full-resolution-review.json"
      )
      |> put_in(
        [:operator_notes, :known_good_transport_review_path],
        "tmp/stale-known-good-transport-review.json"
      )
      |> put_in([:operator_notes, :multi_hop_review_path], "tmp/stale-multi-hop-review.json")
      |> put_in([:operator_notes, :routing_review_path], "tmp/stale-routing-review.json")
      |> put_in([:operator_notes, :security_review_path], "tmp/stale-security-review.json")
      |> put_in([:operator_notes, :ux_review_path], "tmp/stale-ux-review.json")

    review = LocalReleaseCandidateEvidenceReview.review(input)

    assert review.status == :open
    refute review.release_candidate_evidence_complete?

    assert "Operator notes readiness_manifest_path must match top-level readiness_manifest_path." in review.missing

    assert "Operator notes completion_audit_path must match top-level completion_audit_path." in review.missing

    assert "Operator notes completion_audit_plain_text_path must match top-level completion_audit_plain_text_path." in review.missing

    assert "Operator notes completion_blocker_matrix_path must match top-level completion_blocker_matrix_path." in review.missing

    assert "Operator notes release_manifest_path must match top-level release_manifest_path." in review.missing

    assert "Operator notes recent_evidence_inventory_path must match top-level recent_evidence_inventory_path." in review.missing

    assert "Operator notes persistence_lifecycle_plan_path must match top-level persistence_lifecycle_plan_path." in review.missing

    assert "Operator notes lifecycle_review_path must match top-level lifecycle_review_path." in review.missing

    assert "Operator notes ios_parity_review_path must match top-level ios_parity_review_path." in review.missing

    assert "Operator notes full_resolution_review_path must match top-level full_resolution_review_path." in review.missing

    assert "Operator notes known_good_transport_review_path must match top-level known_good_transport_review_path." in review.missing

    assert "Operator notes multi_hop_review_path must match top-level multi_hop_review_path." in review.missing

    assert "Operator notes routing_review_path must match top-level routing_review_path." in review.missing

    assert "Operator notes security_review_path must match top-level security_review_path." in review.missing

    assert "Operator notes ux_review_path must match top-level ux_review_path." in review.missing
  end

  test "persistence lifecycle summary must preserve memory-only default and blocked default claims" do
    input =
      complete_input()
      |> Map.put(:persistence_lifecycle_plan_path, "tmp/local-persistence-lifecycle-plan.json")
      |> put_in([:persistence_lifecycle, :plan_path], "tmp/other-persistence-lifecycle-plan.json")
      |> put_in([:persistence_lifecycle, :plan_version], 2)
      |> put_in([:persistence_lifecycle, :boundary], :other_boundary)
      |> put_in([:persistence_lifecycle, :current_default_mode], :opt_in_durable)
      |> put_in([:persistence_lifecycle, :opt_in_durable_snapshots_available?], false)
      |> put_in([:persistence_lifecycle, :production_default_persistence_allowed?], true)
      |> put_in([:persistence_lifecycle, :default_lifecycle_claim_allowed?], true)
      |> put_in([:persistence_lifecycle, :gate_count], 0)
      |> put_in([:persistence_lifecycle, :blocked_gate_count], 1)

    review = LocalReleaseCandidateEvidenceReview.review(input)

    assert review.status == :open
    refute review.release_candidate_evidence_complete?

    assert "Persistence lifecycle plan_path must match persistence_lifecycle_plan_path." in review.missing

    assert "Persistence lifecycle plan_version must be 1." in review.missing

    assert "Persistence lifecycle boundary must be production_default_local_inbox_persistence_plan." in review.missing

    assert "Persistence lifecycle current_default_mode must be memory_only." in review.missing

    assert "Persistence lifecycle must keep opt-in durable snapshots available." in review.missing

    assert "Persistence lifecycle production_default_persistence_allowed? must remain false." in review.missing

    assert "Persistence lifecycle default_lifecycle_claim_allowed? must remain false." in review.missing

    assert "Persistence lifecycle gate_count must be greater than 0." in review.missing

    assert "Persistence lifecycle blocked_gate_count must equal gate_count." in review.missing
  end

  test "persistence lifecycle summary must explicitly include decision fields" do
    input =
      complete_input()
      |> update_in([:persistence_lifecycle], fn persistence ->
        persistence
        |> Map.delete(:plan_path)
        |> Map.delete(:plan_version)
        |> Map.delete(:boundary)
        |> Map.delete(:current_default_mode)
        |> Map.delete(:opt_in_durable_snapshots_available?)
        |> Map.delete(:production_default_persistence_allowed?)
        |> Map.delete(:default_lifecycle_claim_allowed?)
        |> Map.delete(:gate_count)
        |> Map.delete(:blocked_gate_count)
      end)

    review = LocalReleaseCandidateEvidenceReview.review(input)

    assert "Persistence lifecycle missing plan_path." in review.missing
    assert "Persistence lifecycle missing plan_version." in review.missing
    assert "Persistence lifecycle missing boundary." in review.missing
    assert "Persistence lifecycle missing current_default_mode." in review.missing
    assert "Persistence lifecycle missing opt_in_durable_snapshots_available?." in review.missing

    assert "Persistence lifecycle missing production_default_persistence_allowed?." in review.missing

    assert "Persistence lifecycle missing default_lifecycle_claim_allowed?." in review.missing
    assert "Persistence lifecycle missing gate_count." in review.missing
    assert "Persistence lifecycle missing blocked_gate_count." in review.missing
  end

  test "lifecycle review summary must be ready while preserving foreground and background claim blockers" do
    input =
      complete_input()
      |> Map.put(:lifecycle_review_path, "tmp/local-lifecycle-hardware-review.json")
      |> put_in([:lifecycle_review, :review_path], "tmp/other-lifecycle-hardware-review.json")
      |> put_in([:lifecycle_review, :review_version], 2)
      |> put_in([:lifecycle_review, :boundary], :other_boundary)
      |> put_in([:lifecycle_review, :status], :open)
      |> put_in([:lifecycle_review, :lifecycle_hardware_evidence_complete?], false)
      |> put_in([:lifecycle_review, :android_foreground_service_claim_allowed?], true)
      |> put_in([:lifecycle_review, :android_background_ble_claim_allowed?], true)
      |> put_in([:lifecycle_review, :ios_background_claim_allowed?], true)
      |> put_in([:lifecycle_review, :background_ble_claim_allowed?], true)
      |> put_in([:lifecycle_review, :restart_claim_allowed?], true)
      |> put_in([:lifecycle_review, :scheduled_retry_claim_allowed?], true)
      |> put_in([:lifecycle_review, :background_gossip_claim_allowed?], true)
      |> put_in([:lifecycle_review, :delivery_claim_allowed?], true)

    review = LocalReleaseCandidateEvidenceReview.review(input)

    assert review.status == :open
    refute review.release_candidate_evidence_complete?
    assert "Lifecycle review review_path must match lifecycle_review_path." in review.missing
    assert "Lifecycle review review_version must be 1." in review.missing

    assert "Lifecycle review boundary must be mobile_ble_lifecycle_hardware_evidence_review." in review.missing

    assert "Lifecycle review status must be ready." in review.missing

    assert "Lifecycle review lifecycle_hardware_evidence_complete? must be true." in review.missing

    assert "Lifecycle review android_foreground_service_claim_allowed? must remain false." in review.missing

    assert "Lifecycle review android_background_ble_claim_allowed? must remain false." in review.missing

    assert "Lifecycle review ios_background_claim_allowed? must remain false." in review.missing

    assert "Lifecycle review background_ble_claim_allowed? must remain false." in review.missing
    assert "Lifecycle review restart_claim_allowed? must remain false." in review.missing
    assert "Lifecycle review scheduled_retry_claim_allowed? must remain false." in review.missing

    assert "Lifecycle review background_gossip_claim_allowed? must remain false." in review.missing

    assert "Lifecycle review delivery_claim_allowed? must remain false." in review.missing
  end

  test "lifecycle review summary must explicitly include canonical review fields" do
    input =
      complete_input()
      |> update_in([:lifecycle_review], fn lifecycle_review ->
        lifecycle_review
        |> Map.delete(:review_path)
        |> Map.delete(:review_version)
        |> Map.delete(:boundary)
        |> Map.delete(:status)
        |> Map.delete(:lifecycle_hardware_evidence_complete?)
        |> Map.delete(:android_foreground_service_claim_allowed?)
        |> Map.delete(:android_background_ble_claim_allowed?)
        |> Map.delete(:ios_background_claim_allowed?)
        |> Map.delete(:background_ble_claim_allowed?)
        |> Map.delete(:restart_claim_allowed?)
        |> Map.delete(:scheduled_retry_claim_allowed?)
        |> Map.delete(:background_gossip_claim_allowed?)
        |> Map.delete(:delivery_claim_allowed?)
      end)

    review = LocalReleaseCandidateEvidenceReview.review(input)

    assert "Lifecycle review missing review_path." in review.missing
    assert "Lifecycle review missing review_version." in review.missing
    assert "Lifecycle review missing boundary." in review.missing
    assert "Lifecycle review missing status." in review.missing
    assert "Lifecycle review missing lifecycle_hardware_evidence_complete?." in review.missing

    assert "Lifecycle review missing android_foreground_service_claim_allowed?." in review.missing

    assert "Lifecycle review missing android_background_ble_claim_allowed?." in review.missing
    assert "Lifecycle review missing ios_background_claim_allowed?." in review.missing
    assert "Lifecycle review missing background_ble_claim_allowed?." in review.missing
    assert "Lifecycle review missing restart_claim_allowed?." in review.missing
    assert "Lifecycle review missing scheduled_retry_claim_allowed?." in review.missing
    assert "Lifecycle review missing background_gossip_claim_allowed?." in review.missing
    assert "Lifecycle review missing delivery_claim_allowed?." in review.missing
  end

  test "iOS parity review summary must be ready while preserving iOS claim blockers" do
    input =
      complete_input()
      |> Map.put(:ios_parity_review_path, "tmp/local-ios-parity-hardware-review.json")
      |> put_in([:ios_parity_review, :review_path], "tmp/other-ios-parity-review.json")
      |> put_in([:ios_parity_review, :review_version], 2)
      |> put_in([:ios_parity_review, :boundary], :other_boundary)
      |> put_in([:ios_parity_review, :status], :open)
      |> put_in([:ios_parity_review, :ios_hardware_evidence_complete?], false)
      |> put_in([:ios_parity_review, :ios_participation_claim_allowed?], true)
      |> put_in([:ios_parity_review, :ios_hardware_claim_allowed?], true)
      |> put_in([:ios_parity_review, :ios_legacy_beacon_observe_claim_allowed?], true)
      |> put_in([:ios_parity_review, :ios_legacy_beacon_gossip_claim_allowed?], true)
      |> put_in([:ios_parity_review, :ios_full_envelope_advert_claim_allowed?], true)
      |> put_in([:ios_parity_review, :ios_background_ble_claim_allowed?], true)
      |> put_in([:ios_parity_review, :ios_parity_claim_allowed?], true)

    review = LocalReleaseCandidateEvidenceReview.review(input)

    assert review.status == :open
    refute review.release_candidate_evidence_complete?
    assert "iOS parity review review_path must match ios_parity_review_path." in review.missing
    assert "iOS parity review review_version must be 1." in review.missing

    assert "iOS parity review boundary must be ios_advert_only_hardware_evidence_review." in review.missing

    assert "iOS parity review status must be ready." in review.missing

    assert "iOS parity review ios_hardware_evidence_complete? must be true." in review.missing

    assert "iOS parity review ios_participation_claim_allowed? must remain false." in review.missing

    assert "iOS parity review ios_hardware_claim_allowed? must remain false." in review.missing

    assert "iOS parity review ios_legacy_beacon_observe_claim_allowed? must remain false." in review.missing

    assert "iOS parity review ios_legacy_beacon_gossip_claim_allowed? must remain false." in review.missing

    assert "iOS parity review ios_full_envelope_advert_claim_allowed? must remain false." in review.missing

    assert "iOS parity review ios_background_ble_claim_allowed? must remain false." in review.missing

    assert "iOS parity review ios_parity_claim_allowed? must remain false." in review.missing
  end

  test "iOS parity review summary must explicitly include canonical review fields" do
    input =
      complete_input()
      |> update_in([:ios_parity_review], fn ios_parity_review ->
        ios_parity_review
        |> Map.delete(:review_path)
        |> Map.delete(:review_version)
        |> Map.delete(:boundary)
        |> Map.delete(:status)
        |> Map.delete(:ios_hardware_evidence_complete?)
        |> Map.delete(:ios_participation_claim_allowed?)
        |> Map.delete(:ios_hardware_claim_allowed?)
        |> Map.delete(:ios_legacy_beacon_observe_claim_allowed?)
        |> Map.delete(:ios_legacy_beacon_gossip_claim_allowed?)
        |> Map.delete(:ios_full_envelope_advert_claim_allowed?)
        |> Map.delete(:ios_background_ble_claim_allowed?)
        |> Map.delete(:ios_parity_claim_allowed?)
      end)

    review = LocalReleaseCandidateEvidenceReview.review(input)

    assert "iOS parity review missing review_path." in review.missing
    assert "iOS parity review missing review_version." in review.missing
    assert "iOS parity review missing boundary." in review.missing
    assert "iOS parity review missing status." in review.missing
    assert "iOS parity review missing ios_hardware_evidence_complete?." in review.missing
    assert "iOS parity review missing ios_participation_claim_allowed?." in review.missing
    assert "iOS parity review missing ios_hardware_claim_allowed?." in review.missing

    assert "iOS parity review missing ios_legacy_beacon_observe_claim_allowed?." in review.missing

    assert "iOS parity review missing ios_legacy_beacon_gossip_claim_allowed?." in review.missing

    assert "iOS parity review missing ios_full_envelope_advert_claim_allowed?." in review.missing

    assert "iOS parity review missing ios_background_ble_claim_allowed?." in review.missing
    assert "iOS parity review missing ios_parity_claim_allowed?." in review.missing
  end

  test "full-resolution review summary must be ready while preserving unresolved beacon boundaries" do
    input =
      complete_input()
      |> Map.put(:full_resolution_review_path, "tmp/local-full-resolution-transport-review.json")
      |> put_in(
        [:full_resolution_review, :review_path],
        "tmp/other-full-resolution-review.json"
      )
      |> put_in([:full_resolution_review, :review_version], 2)
      |> put_in([:full_resolution_review, :boundary], :other_boundary)
      |> put_in([:full_resolution_review, :status], :open)
      |> put_in([:full_resolution_review, :full_resolution_transport_evidence_complete?], false)
      |> put_in([:full_resolution_review, :real_fetch_transport_validated?], true)
      |> put_in([:full_resolution_review, :full_message_resolution_claim_allowed?], true)
      |> put_in([:full_resolution_review, :known_good_transport_claim_allowed?], true)
      |> put_in([:full_resolution_review, :gatt_fetch_success_claim_allowed?], true)
      |> put_in([:full_resolution_review, :message_delivery_claim_allowed?], true)
      |> put_in([:full_resolution_review, :trusted_message_claim_allowed?], true)

    review = LocalReleaseCandidateEvidenceReview.review(input)

    assert review.status == :open
    refute review.release_candidate_evidence_complete?

    assert "Full-resolution review review_path must match full_resolution_review_path." in review.missing

    assert "Full-resolution review review_version must be 1." in review.missing

    assert "Full-resolution review boundary must be full_message_resolution_transport_evidence_review." in review.missing

    assert "Full-resolution review status must be ready." in review.missing

    assert "Full-resolution review full_resolution_transport_evidence_complete? must be true." in review.missing

    assert "Full-resolution review real_fetch_transport_validated? must remain false." in review.missing

    assert "Full-resolution review full_message_resolution_claim_allowed? must remain false." in review.missing

    assert "Full-resolution review known_good_transport_claim_allowed? must remain false." in review.missing

    assert "Full-resolution review gatt_fetch_success_claim_allowed? must remain false." in review.missing

    assert "Full-resolution review message_delivery_claim_allowed? must remain false." in review.missing

    assert "Full-resolution review trusted_message_claim_allowed? must remain false." in review.missing
  end

  test "full-resolution review summary must explicitly include canonical review fields" do
    input =
      complete_input()
      |> update_in([:full_resolution_review], fn full_resolution_review ->
        full_resolution_review
        |> Map.delete(:review_path)
        |> Map.delete(:review_version)
        |> Map.delete(:boundary)
        |> Map.delete(:status)
        |> Map.delete(:full_resolution_transport_evidence_complete?)
        |> Map.delete(:real_fetch_transport_validated?)
        |> Map.delete(:full_message_resolution_claim_allowed?)
        |> Map.delete(:known_good_transport_claim_allowed?)
        |> Map.delete(:gatt_fetch_success_claim_allowed?)
        |> Map.delete(:message_delivery_claim_allowed?)
        |> Map.delete(:trusted_message_claim_allowed?)
      end)

    review = LocalReleaseCandidateEvidenceReview.review(input)

    assert "Full-resolution review missing review_path." in review.missing
    assert "Full-resolution review missing review_version." in review.missing
    assert "Full-resolution review missing boundary." in review.missing
    assert "Full-resolution review missing status." in review.missing

    assert "Full-resolution review missing full_resolution_transport_evidence_complete?." in review.missing

    assert "Full-resolution review missing real_fetch_transport_validated?." in review.missing

    assert "Full-resolution review missing full_message_resolution_claim_allowed?." in review.missing

    assert "Full-resolution review missing known_good_transport_claim_allowed?." in review.missing

    assert "Full-resolution review missing gatt_fetch_success_claim_allowed?." in review.missing

    assert "Full-resolution review missing message_delivery_claim_allowed?." in review.missing
    assert "Full-resolution review missing trusted_message_claim_allowed?." in review.missing
  end

  test "known-good transport review summary must be ready while preserving transport blockers" do
    input =
      complete_input()
      |> Map.put(:known_good_transport_review_path, "tmp/local-known-good-transport-review.json")
      |> put_in(
        [:known_good_transport_review, :review_path],
        "tmp/other-known-good-transport-review.json"
      )
      |> put_in([:known_good_transport_review, :review_version], 2)
      |> put_in([:known_good_transport_review, :boundary], :other_boundary)
      |> put_in([:known_good_transport_review, :status], :open)
      |> put_in([:known_good_transport_review, :known_good_transport_evidence_complete?], false)
      |> put_in([:known_good_transport_review, :known_good_transport_claim_allowed?], true)
      |> put_in([:known_good_transport_review, :gatt_fetch_success_claim_allowed?], true)
      |> put_in([:known_good_transport_review, :full_message_resolution_claim_allowed?], true)
      |> put_in([:known_good_transport_review, :message_delivery_claim_allowed?], true)

    review = LocalReleaseCandidateEvidenceReview.review(input)

    assert review.status == :open
    refute review.release_candidate_evidence_complete?

    assert "Known-good transport review review_path must match known_good_transport_review_path." in review.missing

    assert "Known-good transport review review_version must be 1." in review.missing

    assert "Known-good transport review boundary must be known_good_transport_evidence_review." in review.missing

    assert "Known-good transport review status must be ready." in review.missing

    assert "Known-good transport review known_good_transport_evidence_complete? must be true." in review.missing

    assert "Known-good transport review known_good_transport_claim_allowed? must remain false." in review.missing

    assert "Known-good transport review gatt_fetch_success_claim_allowed? must remain false." in review.missing

    assert "Known-good transport review full_message_resolution_claim_allowed? must remain false." in review.missing

    assert "Known-good transport review message_delivery_claim_allowed? must remain false." in review.missing
  end

  test "known-good transport review summary must explicitly include canonical review fields" do
    input =
      complete_input()
      |> update_in([:known_good_transport_review], fn known_good_transport_review ->
        known_good_transport_review
        |> Map.delete(:review_path)
        |> Map.delete(:review_version)
        |> Map.delete(:boundary)
        |> Map.delete(:status)
        |> Map.delete(:known_good_transport_evidence_complete?)
        |> Map.delete(:known_good_transport_claim_allowed?)
        |> Map.delete(:gatt_fetch_success_claim_allowed?)
        |> Map.delete(:full_message_resolution_claim_allowed?)
        |> Map.delete(:message_delivery_claim_allowed?)
      end)

    review = LocalReleaseCandidateEvidenceReview.review(input)

    assert "Known-good transport review missing review_path." in review.missing
    assert "Known-good transport review missing review_version." in review.missing
    assert "Known-good transport review missing boundary." in review.missing
    assert "Known-good transport review missing status." in review.missing

    assert "Known-good transport review missing known_good_transport_evidence_complete?." in review.missing

    assert "Known-good transport review missing known_good_transport_claim_allowed?." in review.missing

    assert "Known-good transport review missing gatt_fetch_success_claim_allowed?." in review.missing

    assert "Known-good transport review missing full_message_resolution_claim_allowed?." in review.missing

    assert "Known-good transport review missing message_delivery_claim_allowed?." in review.missing
  end

  test "multi-hop review summary must be ready while preserving physical proof blockers" do
    input =
      complete_input()
      |> Map.put(:multi_hop_review_path, "tmp/local-multi-hop-hardware-review.json")
      |> put_in([:multi_hop_review, :review_path], "tmp/other-multi-hop-review.json")
      |> put_in([:multi_hop_review, :review_version], 2)
      |> put_in([:multi_hop_review, :boundary], :other_boundary)
      |> put_in([:multi_hop_review, :status], :open)
      |> put_in([:multi_hop_review, :multi_hop_hardware_evidence_complete?], false)
      |> put_in([:multi_hop_review, :multi_hop_physical_proof_present?], true)
      |> put_in([:multi_hop_review, :multi_hop_hardware_gossip_claim_allowed?], true)
      |> put_in([:multi_hop_review, :routed_delivery_claim_allowed?], true)
      |> put_in([:multi_hop_review, :guaranteed_delivery_claim_allowed?], true)
      |> put_in([:multi_hop_review, :trusted_delivery_claim_allowed?], true)
      |> put_in([:multi_hop_review, :background_operation_claim_allowed?], true)

    review = LocalReleaseCandidateEvidenceReview.review(input)

    assert review.status == :open
    refute review.release_candidate_evidence_complete?
    assert "Multi-hop review review_path must match multi_hop_review_path." in review.missing
    assert "Multi-hop review review_version must be 1." in review.missing

    assert "Multi-hop review boundary must be multi_hop_hardware_evidence_review." in review.missing

    assert "Multi-hop review status must be ready." in review.missing

    assert "Multi-hop review multi_hop_hardware_evidence_complete? must be true." in review.missing

    assert "Multi-hop review multi_hop_physical_proof_present? must remain false." in review.missing

    assert "Multi-hop review multi_hop_hardware_gossip_claim_allowed? must remain false." in review.missing

    assert "Multi-hop review routed_delivery_claim_allowed? must remain false." in review.missing

    assert "Multi-hop review guaranteed_delivery_claim_allowed? must remain false." in review.missing

    assert "Multi-hop review trusted_delivery_claim_allowed? must remain false." in review.missing

    assert "Multi-hop review background_operation_claim_allowed? must remain false." in review.missing
  end

  test "multi-hop review summary must explicitly include canonical review fields" do
    input =
      complete_input()
      |> update_in([:multi_hop_review], fn multi_hop_review ->
        multi_hop_review
        |> Map.delete(:review_path)
        |> Map.delete(:review_version)
        |> Map.delete(:boundary)
        |> Map.delete(:status)
        |> Map.delete(:multi_hop_hardware_evidence_complete?)
        |> Map.delete(:multi_hop_physical_proof_present?)
        |> Map.delete(:multi_hop_hardware_gossip_claim_allowed?)
        |> Map.delete(:routed_delivery_claim_allowed?)
        |> Map.delete(:guaranteed_delivery_claim_allowed?)
        |> Map.delete(:trusted_delivery_claim_allowed?)
        |> Map.delete(:background_operation_claim_allowed?)
      end)

    review = LocalReleaseCandidateEvidenceReview.review(input)

    assert "Multi-hop review missing review_path." in review.missing
    assert "Multi-hop review missing review_version." in review.missing
    assert "Multi-hop review missing boundary." in review.missing
    assert "Multi-hop review missing status." in review.missing
    assert "Multi-hop review missing multi_hop_hardware_evidence_complete?." in review.missing
    assert "Multi-hop review missing multi_hop_physical_proof_present?." in review.missing

    assert "Multi-hop review missing multi_hop_hardware_gossip_claim_allowed?." in review.missing

    assert "Multi-hop review missing routed_delivery_claim_allowed?." in review.missing
    assert "Multi-hop review missing guaranteed_delivery_claim_allowed?." in review.missing
    assert "Multi-hop review missing trusted_delivery_claim_allowed?." in review.missing
    assert "Multi-hop review missing background_operation_claim_allowed?." in review.missing
  end

  test "security review summary must be ready while preserving blocked trust claims" do
    input =
      complete_input()
      |> Map.put(:security_review_path, "tmp/local-security-release-review.json")
      |> put_in([:security_review, :review_path], "tmp/other-security-release-review.json")
      |> put_in([:security_review, :review_version], 2)
      |> put_in([:security_review, :boundary], :other_boundary)
      |> put_in([:security_review, :status], :open)
      |> put_in([:security_review, :security_release_evidence_complete?], false)
      |> put_in([:security_review, :authenticated_peer_identity_claim_allowed?], true)
      |> put_in([:security_review, :authenticated_message_claim_allowed?], true)
      |> put_in([:security_review, :trusted_message_claim_allowed?], true)
      |> put_in([:security_review, :trusted_delivery_claim_allowed?], true)

    review = LocalReleaseCandidateEvidenceReview.review(input)

    assert review.status == :open
    refute review.release_candidate_evidence_complete?
    assert "Security review review_path must match security_review_path." in review.missing
    assert "Security review review_version must be 1." in review.missing

    assert "Security review boundary must be local_security_release_evidence_review." in review.missing

    assert "Security review status must be ready." in review.missing

    assert "Security review security_release_evidence_complete? must be true." in review.missing

    assert "Security review authenticated_peer_identity_claim_allowed? must remain false." in review.missing

    assert "Security review authenticated_message_claim_allowed? must remain false." in review.missing

    assert "Security review trusted_message_claim_allowed? must remain false." in review.missing

    assert "Security review trusted_delivery_claim_allowed? must remain false." in review.missing
  end

  test "security review summary must explicitly include canonical review fields" do
    input =
      complete_input()
      |> update_in([:security_review], fn security_review ->
        security_review
        |> Map.delete(:review_path)
        |> Map.delete(:review_version)
        |> Map.delete(:boundary)
        |> Map.delete(:status)
        |> Map.delete(:security_release_evidence_complete?)
        |> Map.delete(:authenticated_peer_identity_claim_allowed?)
        |> Map.delete(:authenticated_message_claim_allowed?)
        |> Map.delete(:trusted_message_claim_allowed?)
        |> Map.delete(:trusted_delivery_claim_allowed?)
      end)

    review = LocalReleaseCandidateEvidenceReview.review(input)

    assert "Security review missing review_path." in review.missing
    assert "Security review missing review_version." in review.missing
    assert "Security review missing boundary." in review.missing
    assert "Security review missing status." in review.missing
    assert "Security review missing security_release_evidence_complete?." in review.missing

    assert "Security review missing authenticated_peer_identity_claim_allowed?." in review.missing

    assert "Security review missing authenticated_message_claim_allowed?." in review.missing
    assert "Security review missing trusted_message_claim_allowed?." in review.missing
    assert "Security review missing trusted_delivery_claim_allowed?." in review.missing
  end

  test "routing review summary must be ready while preserving non-routing claims" do
    input =
      complete_input()
      |> Map.put(:routing_review_path, "tmp/local-routing-production-review.json")
      |> put_in([:routing_review, :review_path], "tmp/other-routing-production-review.json")
      |> put_in([:routing_review, :review_version], 2)
      |> put_in([:routing_review, :boundary], :other_boundary)
      |> put_in([:routing_review, :status], :open)
      |> put_in([:routing_review, :production_routing_evidence_complete?], false)
      |> put_in([:routing_review, :route_table_claim_allowed?], true)
      |> put_in([:routing_review, :route_selection_claim_allowed?], true)
      |> put_in([:routing_review, :forwarding_claim_allowed?], true)
      |> put_in([:routing_review, :routed_delivery_claim_allowed?], true)
      |> put_in([:routing_review, :guaranteed_delivery_claim_allowed?], true)
      |> put_in([:routing_review, :multi_hop_hardware_claim_allowed?], true)

    review = LocalReleaseCandidateEvidenceReview.review(input)

    assert review.status == :open
    refute review.release_candidate_evidence_complete?
    assert "Routing review review_path must match routing_review_path." in review.missing
    assert "Routing review review_version must be 1." in review.missing
    assert "Routing review boundary must be production_routing_evidence_review." in review.missing
    assert "Routing review status must be ready." in review.missing
    assert "Routing review production_routing_evidence_complete? must be true." in review.missing
    assert "Routing review route_table_claim_allowed? must remain false." in review.missing
    assert "Routing review route_selection_claim_allowed? must remain false." in review.missing
    assert "Routing review forwarding_claim_allowed? must remain false." in review.missing
    assert "Routing review routed_delivery_claim_allowed? must remain false." in review.missing

    assert "Routing review guaranteed_delivery_claim_allowed? must remain false." in review.missing

    assert "Routing review multi_hop_hardware_claim_allowed? must remain false." in review.missing
  end

  test "routing review summary must explicitly include canonical review fields" do
    input =
      complete_input()
      |> update_in([:routing_review], fn routing_review ->
        routing_review
        |> Map.delete(:review_path)
        |> Map.delete(:review_version)
        |> Map.delete(:boundary)
        |> Map.delete(:status)
        |> Map.delete(:production_routing_evidence_complete?)
        |> Map.delete(:route_table_claim_allowed?)
        |> Map.delete(:route_selection_claim_allowed?)
        |> Map.delete(:forwarding_claim_allowed?)
        |> Map.delete(:routed_delivery_claim_allowed?)
        |> Map.delete(:guaranteed_delivery_claim_allowed?)
        |> Map.delete(:multi_hop_hardware_claim_allowed?)
      end)

    review = LocalReleaseCandidateEvidenceReview.review(input)

    assert "Routing review missing review_path." in review.missing
    assert "Routing review missing review_version." in review.missing
    assert "Routing review missing boundary." in review.missing
    assert "Routing review missing status." in review.missing
    assert "Routing review missing production_routing_evidence_complete?." in review.missing
    assert "Routing review missing route_table_claim_allowed?." in review.missing
    assert "Routing review missing route_selection_claim_allowed?." in review.missing
    assert "Routing review missing forwarding_claim_allowed?." in review.missing
    assert "Routing review missing routed_delivery_claim_allowed?." in review.missing
    assert "Routing review missing guaranteed_delivery_claim_allowed?." in review.missing
    assert "Routing review missing multi_hop_hardware_claim_allowed?." in review.missing
  end

  test "UX review summary must be ready and match the release candidate UX review path" do
    input =
      complete_input()
      |> Map.put(:ux_review_path, "tmp/local-inbox-ux-review.json")
      |> put_in([:ux_review, :review_path], "tmp/other-ux-review.json")
      |> put_in([:ux_review, :status], :open)
      |> put_in([:ux_review, :target_device_count], 0)
      |> put_in([:ux_review, :all_target_devices_have_state_coverage?], false)
      |> put_in([:ux_review, :all_target_devices_have_interaction_coverage?], false)
      |> put_in([:ux_review, :all_target_devices_have_selected_detail_coverage?], false)
      |> put_in([:ux_review, :all_target_devices_have_selected_detail_copy_anchors?], false)
      |> put_in([:ux_review, :all_target_devices_copy_reviewed?], false)
      |> put_in([:ux_review, :all_target_devices_density_reviewed?], false)

    review = LocalReleaseCandidateEvidenceReview.review(input)

    assert "UX review review_path must match ux_review_path." in review.missing
    assert "UX review status must be ready." in review.missing
    assert "UX review target_device_count must be greater than 0." in review.missing
    assert "UX review missing state coverage." in review.missing
    assert "UX review missing interaction coverage." in review.missing
    assert "UX review missing selected detail coverage." in review.missing

    assert "UX review missing selected detail limitation_copy, next_action_copy, and blocked_claim_copy coverage." in
             review.missing

    assert "UX review missing copy review coverage." in review.missing
    assert "UX review missing density review coverage." in review.missing
  end

  test "UX review summary must carry canonical review identity and blocked claim flags" do
    input =
      complete_input()
      |> put_in([:ux_review, :review_version], 2)
      |> put_in([:ux_review, :boundary], :other_boundary)
      |> put_in([:ux_review, :on_device_ux_evidence_complete?], false)
      |> put_in([:ux_review, :production_ux_claim_allowed?], true)
      |> put_in([:ux_review, :delivery_claim_allowed?], true)
      |> put_in([:ux_review, :trusted_delivery_claim_allowed?], true)
      |> put_in([:ux_review, :routing_claim_allowed?], true)

    review = LocalReleaseCandidateEvidenceReview.review(input)

    assert review.status == :open
    refute review.release_candidate_evidence_complete?
    assert "UX review review_version must be 1." in review.missing

    assert "UX review boundary must be nearby_messages_on_device_ux_evidence." in review.missing

    assert "UX review on_device_ux_evidence_complete? must be true." in review.missing

    assert "UX review production_ux_claim_allowed? must remain false." in review.missing

    assert "UX review delivery_claim_allowed? must remain false." in review.missing

    assert "UX review trusted_delivery_claim_allowed? must remain false." in review.missing

    assert "UX review routing_claim_allowed? must remain false." in review.missing
  end

  test "UX review summary must explicitly include canonical review identity fields" do
    input =
      complete_input()
      |> update_in([:ux_review], fn ux_review ->
        ux_review
        |> Map.delete(:review_version)
        |> Map.delete(:boundary)
        |> Map.delete(:on_device_ux_evidence_complete?)
        |> Map.delete(:production_ux_claim_allowed?)
        |> Map.delete(:delivery_claim_allowed?)
        |> Map.delete(:trusted_delivery_claim_allowed?)
        |> Map.delete(:routing_claim_allowed?)
        |> Map.delete(:all_target_devices_have_selected_detail_copy_anchors?)
      end)

    review = LocalReleaseCandidateEvidenceReview.review(input)

    assert "UX review missing review_version." in review.missing
    assert "UX review missing boundary." in review.missing
    assert "UX review missing on_device_ux_evidence_complete?." in review.missing
    assert "UX review missing production_ux_claim_allowed?." in review.missing
    assert "UX review missing delivery_claim_allowed?." in review.missing
    assert "UX review missing trusted_delivery_claim_allowed?." in review.missing
    assert "UX review missing routing_claim_allowed?." in review.missing

    assert "UX review missing all_target_devices_have_selected_detail_copy_anchors?." in review.missing
  end

  test "json review is machine readable" do
    review = LocalReleaseCandidateEvidenceReview.json_review(complete_input())

    assert review["review_version"] == 1
    assert review["status"] == "ready"
    assert review["whole_project_complete?"] == false
    assert review["release_candidate_evidence_complete?"] == true
    assert review["allowed_wording"] == LocalReleaseCandidateEvidenceReview.allowed_wording()
    assert review["persistence_lifecycle"]["plan_version"] == 1

    assert review["persistence_lifecycle"]["boundary"] ==
             "production_default_local_inbox_persistence_plan"

    assert review["persistence_lifecycle"]["current_default_mode"] == "memory_only"

    assert review["persistence_lifecycle"]["production_default_persistence_allowed?"] == false

    assert review["lifecycle_review"]["review_version"] == 1

    assert review["lifecycle_review"]["boundary"] ==
             "mobile_ble_lifecycle_hardware_evidence_review"

    assert review["lifecycle_review"]["lifecycle_hardware_evidence_complete?"] == true
    assert review["lifecycle_review"]["background_ble_claim_allowed?"] == false
    assert review["lifecycle_review"]["delivery_claim_allowed?"] == false
    assert review["ios_parity_review"]["review_version"] == 1
    assert review["ios_parity_review"]["boundary"] == "ios_advert_only_hardware_evidence_review"
    assert review["ios_parity_review"]["ios_hardware_evidence_complete?"] == true
    assert review["ios_parity_review"]["ios_participation_claim_allowed?"] == false
    assert review["ios_parity_review"]["ios_parity_claim_allowed?"] == false
    assert review["full_resolution_review"]["review_version"] == 1

    assert review["full_resolution_review"]["boundary"] ==
             "full_message_resolution_transport_evidence_review"

    assert review["full_resolution_review"]["full_resolution_transport_evidence_complete?"] ==
             true

    assert review["full_resolution_review"]["real_fetch_transport_validated?"] == false

    assert review["full_resolution_review"]["full_message_resolution_claim_allowed?"] == false

    assert review["full_resolution_review"]["message_delivery_claim_allowed?"] == false
    assert review["known_good_transport_review"]["review_version"] == 1

    assert review["known_good_transport_review"]["boundary"] ==
             "known_good_transport_evidence_review"

    assert review["known_good_transport_review"]["known_good_transport_evidence_complete?"] ==
             true

    assert review["known_good_transport_review"]["known_good_transport_claim_allowed?"] ==
             false

    assert review["known_good_transport_review"]["gatt_fetch_success_claim_allowed?"] == false

    assert review["known_good_transport_review"]["full_message_resolution_claim_allowed?"] ==
             false

    assert review["multi_hop_review"]["review_version"] == 1

    assert review["multi_hop_review"]["boundary"] ==
             "multi_hop_hardware_evidence_review"

    assert review["multi_hop_review"]["multi_hop_hardware_evidence_complete?"] == true
    assert review["multi_hop_review"]["multi_hop_physical_proof_present?"] == false
    assert review["multi_hop_review"]["routed_delivery_claim_allowed?"] == false
    assert review["security_review"]["review_version"] == 1
    assert review["security_review"]["boundary"] == "local_security_release_evidence_review"
    assert review["security_review"]["security_release_evidence_complete?"] == true
    assert review["security_review"]["trusted_message_claim_allowed?"] == false
    assert review["security_review"]["trusted_delivery_claim_allowed?"] == false
    assert review["routing_review"]["review_version"] == 1
    assert review["routing_review"]["boundary"] == "production_routing_evidence_review"
    assert review["routing_review"]["production_routing_evidence_complete?"] == true
    assert review["routing_review"]["route_selection_claim_allowed?"] == false
    assert review["routing_review"]["routed_delivery_claim_allowed?"] == false
    assert review["ux_review"]["review_version"] == 1
    assert review["ux_review"]["boundary"] == "nearby_messages_on_device_ux_evidence"
    assert review["ux_review"]["on_device_ux_evidence_complete?"] == true
    assert review["ux_review"]["delivery_claim_allowed?"] == false
    assert review["ux_review"]["status"] == "ready"
    assert review["ux_review"]["all_target_devices_have_selected_detail_coverage?"] == true
    assert review["ux_review"]["all_target_devices_have_selected_detail_copy_anchors?"] == true
  end

  test "template input exposes release evidence shape but remains incomplete" do
    template = LocalReleaseCandidateEvidenceReview.template_input()

    assert template["allowed_wording"] == nil
    assert template["readiness_manifest_path"] == ""
    assert template["completion_audit_path"] == ""
    assert template["completion_audit_plain_text_path"] == ""
    assert template["completion_blocker_matrix_path"] == ""
    assert template["release_manifest_path"] == ""
    assert template["recent_evidence_inventory_path"] == ""
    assert template["advert_gossip_audit_path"] == ""
    assert template["persistence_lifecycle_plan_path"] == ""
    assert template["persistence_lifecycle"]["plan_path"] == ""
    assert template["persistence_lifecycle"]["plan_version"] == 1

    assert template["persistence_lifecycle"]["boundary"] ==
             "production_default_local_inbox_persistence_plan"

    assert template["persistence_lifecycle"]["current_default_mode"] == "memory_only"
    assert template["persistence_lifecycle"]["opt_in_durable_snapshots_available?"] == false
    assert template["persistence_lifecycle"]["production_default_persistence_allowed?"] == false
    assert template["persistence_lifecycle"]["default_lifecycle_claim_allowed?"] == false
    assert template["persistence_lifecycle"]["gate_count"] == 0
    assert template["persistence_lifecycle"]["blocked_gate_count"] == 0
    assert template["lifecycle_review_path"] == ""
    assert template["lifecycle_review"]["review_path"] == ""
    assert template["lifecycle_review"]["review_version"] == 1

    assert template["lifecycle_review"]["boundary"] ==
             "mobile_ble_lifecycle_hardware_evidence_review"

    assert template["lifecycle_review"]["status"] == ""
    assert template["lifecycle_review"]["lifecycle_hardware_evidence_complete?"] == false
    assert template["lifecycle_review"]["android_foreground_service_claim_allowed?"] == false
    assert template["lifecycle_review"]["android_background_ble_claim_allowed?"] == false
    assert template["lifecycle_review"]["ios_background_claim_allowed?"] == false
    assert template["lifecycle_review"]["background_ble_claim_allowed?"] == false
    assert template["lifecycle_review"]["restart_claim_allowed?"] == false
    assert template["lifecycle_review"]["scheduled_retry_claim_allowed?"] == false
    assert template["lifecycle_review"]["background_gossip_claim_allowed?"] == false
    assert template["lifecycle_review"]["delivery_claim_allowed?"] == false
    assert template["ios_parity_review_path"] == ""
    assert template["ios_parity_review"]["review_path"] == ""
    assert template["ios_parity_review"]["review_version"] == 1
    assert template["ios_parity_review"]["boundary"] == "ios_advert_only_hardware_evidence_review"
    assert template["ios_parity_review"]["status"] == ""
    assert template["ios_parity_review"]["ios_hardware_evidence_complete?"] == false
    assert template["ios_parity_review"]["ios_participation_claim_allowed?"] == false
    assert template["ios_parity_review"]["ios_hardware_claim_allowed?"] == false

    assert template["ios_parity_review"]["ios_legacy_beacon_observe_claim_allowed?"] == false

    assert template["ios_parity_review"]["ios_legacy_beacon_gossip_claim_allowed?"] == false

    assert template["ios_parity_review"]["ios_full_envelope_advert_claim_allowed?"] == false
    assert template["ios_parity_review"]["ios_background_ble_claim_allowed?"] == false
    assert template["ios_parity_review"]["ios_parity_claim_allowed?"] == false
    assert template["full_resolution_review_path"] == ""
    assert template["full_resolution_review"]["review_path"] == ""
    assert template["full_resolution_review"]["review_version"] == 1

    assert template["full_resolution_review"]["boundary"] ==
             "full_message_resolution_transport_evidence_review"

    assert template["full_resolution_review"]["status"] == ""

    assert template["full_resolution_review"][
             "full_resolution_transport_evidence_complete?"
           ] == false

    assert template["full_resolution_review"]["real_fetch_transport_validated?"] == false

    assert template["full_resolution_review"]["full_message_resolution_claim_allowed?"] ==
             false

    assert template["full_resolution_review"]["known_good_transport_claim_allowed?"] == false
    assert template["full_resolution_review"]["gatt_fetch_success_claim_allowed?"] == false
    assert template["full_resolution_review"]["message_delivery_claim_allowed?"] == false
    assert template["full_resolution_review"]["trusted_message_claim_allowed?"] == false
    assert template["known_good_transport_review_path"] == ""
    assert template["known_good_transport_review"]["review_path"] == ""
    assert template["known_good_transport_review"]["review_version"] == 1

    assert template["known_good_transport_review"]["boundary"] ==
             "known_good_transport_evidence_review"

    assert template["known_good_transport_review"]["status"] == ""

    assert template["known_good_transport_review"]["known_good_transport_evidence_complete?"] ==
             false

    assert template["known_good_transport_review"]["known_good_transport_claim_allowed?"] ==
             false

    assert template["known_good_transport_review"]["gatt_fetch_success_claim_allowed?"] ==
             false

    assert template["known_good_transport_review"]["full_message_resolution_claim_allowed?"] ==
             false

    assert template["known_good_transport_review"]["message_delivery_claim_allowed?"] == false
    assert template["multi_hop_review_path"] == ""
    assert template["multi_hop_review"]["review_path"] == ""
    assert template["multi_hop_review"]["review_version"] == 1
    assert template["multi_hop_review"]["boundary"] == "multi_hop_hardware_evidence_review"
    assert template["multi_hop_review"]["status"] == ""
    assert template["multi_hop_review"]["multi_hop_hardware_evidence_complete?"] == false
    assert template["multi_hop_review"]["multi_hop_physical_proof_present?"] == false

    assert template["multi_hop_review"]["multi_hop_hardware_gossip_claim_allowed?"] ==
             false

    assert template["multi_hop_review"]["routed_delivery_claim_allowed?"] == false
    assert template["multi_hop_review"]["guaranteed_delivery_claim_allowed?"] == false
    assert template["multi_hop_review"]["trusted_delivery_claim_allowed?"] == false
    assert template["multi_hop_review"]["background_operation_claim_allowed?"] == false
    assert template["security_review_path"] == ""
    assert template["security_review"]["review_path"] == ""
    assert template["security_review"]["review_version"] == 1
    assert template["security_review"]["boundary"] == "local_security_release_evidence_review"
    assert template["security_review"]["status"] == ""
    assert template["security_review"]["security_release_evidence_complete?"] == false
    assert template["security_review"]["authenticated_peer_identity_claim_allowed?"] == false
    assert template["security_review"]["authenticated_message_claim_allowed?"] == false
    assert template["security_review"]["trusted_message_claim_allowed?"] == false
    assert template["security_review"]["trusted_delivery_claim_allowed?"] == false
    assert template["routing_review_path"] == ""
    assert template["routing_review"]["review_path"] == ""
    assert template["routing_review"]["review_version"] == 1
    assert template["routing_review"]["boundary"] == "production_routing_evidence_review"
    assert template["routing_review"]["status"] == ""
    assert template["routing_review"]["production_routing_evidence_complete?"] == false
    assert template["routing_review"]["route_table_claim_allowed?"] == false
    assert template["routing_review"]["route_selection_claim_allowed?"] == false
    assert template["routing_review"]["forwarding_claim_allowed?"] == false
    assert template["routing_review"]["routed_delivery_claim_allowed?"] == false
    assert template["routing_review"]["guaranteed_delivery_claim_allowed?"] == false
    assert template["routing_review"]["multi_hop_hardware_claim_allowed?"] == false
    assert template["ux_review_path"] == ""
    assert template["ux_review"]["review_path"] == ""
    assert template["ux_review"]["review_version"] == 1
    assert template["ux_review"]["boundary"] == "nearby_messages_on_device_ux_evidence"
    assert template["ux_review"]["status"] == ""
    assert template["ux_review"]["on_device_ux_evidence_complete?"] == false
    assert template["ux_review"]["production_ux_claim_allowed?"] == false
    assert template["ux_review"]["delivery_claim_allowed?"] == false
    assert template["ux_review"]["trusted_delivery_claim_allowed?"] == false
    assert template["ux_review"]["routing_claim_allowed?"] == false
    assert template["ux_review"]["target_device_count"] == 0
    assert template["ux_review"]["all_target_devices_have_state_coverage?"] == false

    [attachment] = template["hardware_attachments"]
    assert attachment["device_model"] == ""
    assert attachment["gate_ids"] == []

    assert attachment["evidence_types_by_gate"] ==
             LocalReleaseCandidateEvidenceReview.required_gate_evidence_types()
             |> Map.new(fn {gate_id, evidence_type} ->
               {Atom.to_string(gate_id), Atom.to_string(evidence_type)}
             end)

    assert template["operator_notes"]["allowed_wording"] ==
             LocalReleaseCandidateEvidenceReview.allowed_wording()

    assert template["operator_notes"]["blocked_claims_called_out"] == []
    assert template["operator_notes"]["open_hardware_gate_ids_called_out"] == []
    assert template["operator_notes"]["completion_audit_plain_text_path"] == ""
    assert template["operator_notes"]["persistence_lifecycle_plan_path"] == ""
    assert template["operator_notes"]["lifecycle_review_path"] == ""
    assert template["operator_notes"]["ios_parity_review_path"] == ""
    assert template["operator_notes"]["full_resolution_review_path"] == ""
    assert template["operator_notes"]["known_good_transport_review_path"] == ""
    assert template["operator_notes"]["multi_hop_review_path"] == ""
    assert template["operator_notes"]["routing_review_path"] == ""
    assert template["operator_notes"]["security_review_path"] == ""
    assert template["operator_notes"]["ux_review_path"] == ""

    review = LocalReleaseCandidateEvidenceReview.review(template)

    assert review.status == :open
    refute review.release_candidate_evidence_complete?
    refute review.whole_project_complete?
    assert "Hardware attachment 1 missing device_model." in review.missing

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "Operator notes missing blocked claim callouts")
           )
  end

  test "review accepts JSON-style string keyed input" do
    input =
      complete_input()
      |> JSON.encode!()
      |> JSON.decode!()

    review = LocalReleaseCandidateEvidenceReview.review(input)

    assert review.status == :ready
    assert review.release_candidate_evidence_complete?
    assert review.missing == []
  end

  defp complete_input do
    %{
      readiness_manifest_path: "tmp/local-readiness.json",
      release_manifest_path: "tmp/local-release.json",
      recent_evidence_inventory_path: "tmp/local-release-recent-evidence.json",
      completion_audit_path: "tmp/local-completion-audit.json",
      completion_audit_plain_text_path: "tmp/local-completion-audit.txt",
      completion_blocker_matrix_path: "tmp/local-completion-blocker-matrix.json",
      advert_gossip_audit_path: "tmp/advert-gossip-audit.txt",
      persistence_lifecycle_plan_path: "tmp/local-persistence-lifecycle-plan.json",
      persistence_lifecycle: %{
        plan_path: "tmp/local-persistence-lifecycle-plan.json",
        plan_version: 1,
        boundary: :production_default_local_inbox_persistence_plan,
        current_default_mode: :memory_only,
        opt_in_durable_snapshots_available?: true,
        production_default_persistence_allowed?: false,
        default_lifecycle_claim_allowed?: false,
        gate_count: 6,
        blocked_gate_count: 6
      },
      lifecycle_review_path: "tmp/local-lifecycle-hardware-review.json",
      lifecycle_review: %{
        review_path: "tmp/local-lifecycle-hardware-review.json",
        review_version: 1,
        boundary: :mobile_ble_lifecycle_hardware_evidence_review,
        status: :ready,
        lifecycle_hardware_evidence_complete?: true,
        android_foreground_service_claim_allowed?: false,
        android_background_ble_claim_allowed?: false,
        ios_background_claim_allowed?: false,
        background_ble_claim_allowed?: false,
        restart_claim_allowed?: false,
        scheduled_retry_claim_allowed?: false,
        background_gossip_claim_allowed?: false,
        delivery_claim_allowed?: false
      },
      ios_parity_review_path: "tmp/local-ios-parity-hardware-review.json",
      ios_parity_review: %{
        review_path: "tmp/local-ios-parity-hardware-review.json",
        review_version: 1,
        boundary: :ios_advert_only_hardware_evidence_review,
        status: :ready,
        ios_hardware_evidence_complete?: true,
        ios_participation_claim_allowed?: false,
        ios_hardware_claim_allowed?: false,
        ios_legacy_beacon_observe_claim_allowed?: false,
        ios_legacy_beacon_gossip_claim_allowed?: false,
        ios_full_envelope_advert_claim_allowed?: false,
        ios_background_ble_claim_allowed?: false,
        ios_parity_claim_allowed?: false
      },
      full_resolution_review_path: "tmp/local-full-resolution-transport-review.json",
      full_resolution_review: %{
        review_path: "tmp/local-full-resolution-transport-review.json",
        review_version: 1,
        boundary: :full_message_resolution_transport_evidence_review,
        status: :ready,
        full_resolution_transport_evidence_complete?: true,
        real_fetch_transport_validated?: false,
        full_message_resolution_claim_allowed?: false,
        known_good_transport_claim_allowed?: false,
        gatt_fetch_success_claim_allowed?: false,
        message_delivery_claim_allowed?: false,
        trusted_message_claim_allowed?: false
      },
      known_good_transport_review_path: "tmp/local-known-good-transport-review.json",
      known_good_transport_review: %{
        review_path: "tmp/local-known-good-transport-review.json",
        review_version: 1,
        boundary: :known_good_transport_evidence_review,
        status: :ready,
        known_good_transport_evidence_complete?: true,
        known_good_transport_claim_allowed?: false,
        gatt_fetch_success_claim_allowed?: false,
        full_message_resolution_claim_allowed?: false,
        message_delivery_claim_allowed?: false
      },
      multi_hop_review_path: "tmp/local-multi-hop-hardware-review.json",
      multi_hop_review: %{
        review_path: "tmp/local-multi-hop-hardware-review.json",
        review_version: 1,
        boundary: :multi_hop_hardware_evidence_review,
        status: :ready,
        multi_hop_hardware_evidence_complete?: true,
        multi_hop_physical_proof_present?: false,
        multi_hop_hardware_gossip_claim_allowed?: false,
        routed_delivery_claim_allowed?: false,
        guaranteed_delivery_claim_allowed?: false,
        trusted_delivery_claim_allowed?: false,
        background_operation_claim_allowed?: false
      },
      security_review_path: "tmp/local-security-release-review.json",
      security_review: %{
        review_path: "tmp/local-security-release-review.json",
        review_version: 1,
        boundary: :local_security_release_evidence_review,
        status: :ready,
        security_release_evidence_complete?: true,
        authenticated_peer_identity_claim_allowed?: false,
        authenticated_message_claim_allowed?: false,
        trusted_message_claim_allowed?: false,
        trusted_delivery_claim_allowed?: false
      },
      routing_review_path: "tmp/local-routing-production-review.json",
      routing_review: %{
        review_path: "tmp/local-routing-production-review.json",
        review_version: 1,
        boundary: :production_routing_evidence_review,
        status: :ready,
        production_routing_evidence_complete?: true,
        route_table_claim_allowed?: false,
        route_selection_claim_allowed?: false,
        forwarding_claim_allowed?: false,
        routed_delivery_claim_allowed?: false,
        guaranteed_delivery_claim_allowed?: false,
        multi_hop_hardware_claim_allowed?: false
      },
      ux_review_path: "tmp/local-inbox-ux-review.json",
      ux_review: %{
        review_path: "tmp/local-inbox-ux-review.json",
        review_version: 1,
        boundary: :nearby_messages_on_device_ux_evidence,
        status: :ready,
        on_device_ux_evidence_complete?: true,
        production_ux_claim_allowed?: false,
        delivery_claim_allowed?: false,
        trusted_delivery_claim_allowed?: false,
        routing_claim_allowed?: false,
        target_device_count: 1,
        all_target_devices_have_state_coverage?: true,
        all_target_devices_have_interaction_coverage?: true,
        all_target_devices_have_selected_detail_coverage?: true,
        all_target_devices_have_selected_detail_copy_anchors?: true,
        all_target_devices_copy_reviewed?: true,
        all_target_devices_density_reviewed?: true
      },
      hardware_attachments: [
        %{
          device_model: "SM-T577U",
          os_or_api_version: "Android API 30",
          role: "sender",
          command_or_harness: "scripts/android_ble_message_delivery_two_device.sh",
          summary_path: "artifacts/meshx-android-m59-gossip-live/summary.json",
          raw_log_path: "artifacts/meshx-android-m59-gossip-live/sender.logcat",
          gate_ids: [:android_legacy_beacon_gossip_one_hop],
          evidence_types_by_gate: %{
            android_legacy_beacon_gossip_one_hop: :android_legacy_beacon_gossip_summary
          }
        }
      ],
      operator_notes: %{
        notes_path: "docs/local_ble_release_artifact_bundle.md",
        allowed_wording: LocalReleaseCandidateEvidenceReview.allowed_wording(),
        blocked_claims_called_out: LocalReleaseCandidateEvidenceReview.required_blocked_claims(),
        open_hardware_gate_ids_called_out: [
          :android_full_envelope_advert_pair,
          :gatt_known_good_fetch,
          :advert_gossip_multi_hop_hardware,
          :ios_advert_only_participation
        ],
        readiness_manifest_path: "tmp/local-readiness.json",
        completion_audit_path: "tmp/local-completion-audit.json",
        completion_audit_plain_text_path: "tmp/local-completion-audit.txt",
        completion_blocker_matrix_path: "tmp/local-completion-blocker-matrix.json",
        release_manifest_path: "tmp/local-release.json",
        recent_evidence_inventory_path: "tmp/local-release-recent-evidence.json",
        persistence_lifecycle_plan_path: "tmp/local-persistence-lifecycle-plan.json",
        lifecycle_review_path: "tmp/local-lifecycle-hardware-review.json",
        ios_parity_review_path: "tmp/local-ios-parity-hardware-review.json",
        full_resolution_review_path: "tmp/local-full-resolution-transport-review.json",
        known_good_transport_review_path: "tmp/local-known-good-transport-review.json",
        multi_hop_review_path: "tmp/local-multi-hop-hardware-review.json",
        routing_review_path: "tmp/local-routing-production-review.json",
        security_review_path: "tmp/local-security-release-review.json",
        ux_review_path: "tmp/local-inbox-ux-review.json"
      }
    }
  end
end
