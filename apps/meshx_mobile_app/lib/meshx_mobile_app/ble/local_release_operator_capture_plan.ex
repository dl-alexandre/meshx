defmodule MeshxMobileApp.BLE.LocalReleaseOperatorCapturePlan do
  @moduledoc """
  Operator capture plan for advert-only local release-candidate evidence.

  The plan turns `LocalReleaseCandidateEvidenceReview` requirements into
  concrete artifact slots that can be filled before operator release review.
  It does not inspect hardware, scan, advertise, fetch, route, persist, ACK,
  retry, encrypt, authenticate, run background work, or mark a release
  candidate complete.
  """

  alias MeshxMobileApp.BLE.{
    LocalReleaseCandidateEvidenceReview,
    LocalReleaseEvidenceManifest
  }

  @manifest_paths [
    :readiness_manifest_path,
    :release_manifest_path,
    :completion_audit_path,
    :completion_audit_plain_text_path,
    :focused_remaining_items_audit_path,
    :focused_remaining_items_plain_text_path,
    :direct_full_mx_aux_validation_checklist_path,
    :upstream_patch_maintainer_handoff_path,
    :completion_blocker_matrix_path,
    :recent_evidence_inventory_path,
    :advert_gossip_audit_path
  ]

  @review_paths [
    :persistence_lifecycle_plan_path,
    :lifecycle_review_path,
    :ios_parity_review_path,
    :full_resolution_review_path,
    :known_good_transport_review_path,
    :multi_hop_review_path,
    :routing_review_path,
    :security_review_path,
    :ux_review_path
  ]

  @spec snapshot() :: map()
  def snapshot do
    review = LocalReleaseCandidateEvidenceReview
    open_gate_ids = open_hardware_gate_ids()

    %{
      plan_version: 1,
      boundary: :local_release_operator_capture_plan,
      status: :open,
      mode: :advertisement_only_local_mesh,
      release_candidate_complete?: false,
      release_candidate_evidence_complete?: false,
      whole_project_complete?: false,
      release_candidate_claim_allowed?: false,
      delivery_claim_allowed?: false,
      trusted_delivery_claim_allowed?: false,
      routed_delivery_claim_allowed?: false,
      background_operation_claim_allowed?: false,
      ios_parity_claim_allowed?: false,
      allowed_wording: review.allowed_wording(),
      required_blocked_claims: review.required_blocked_claims(),
      required_gate_evidence_types: review.required_gate_evidence_types(),
      open_hardware_gate_ids: open_gate_ids,
      open_hardware_gate_count: length(open_gate_ids),
      capture_sections: capture_sections(review, open_gate_ids),
      review_commands: review_commands(),
      artifact_root: "artifacts/local-ble/<run-id>/release-candidate/",
      notes: [
        "This plan is an operator capture checklist, not evidence by itself.",
        "Release-candidate review must attach concrete manifests, review summaries, hardware logs, and operator wording before evidence is ready.",
        "Allowed wording remains limited to messages seen nearby from passive BLE advertisement observations.",
        "Whole-project completion, delivery, trust, routing, background behavior, full-resolution, multi-hop hardware, and iOS parity claims remain blocked."
      ]
    }
  end

  @spec json_snapshot() :: map()
  def json_snapshot do
    snapshot()
    |> JSON.encode!()
    |> JSON.decode!()
  end

  defp open_hardware_gate_ids do
    LocalReleaseEvidenceManifest.open_entries()
    |> Enum.map(& &1.gate_id)
  end

  defp capture_sections(review, open_gate_ids) do
    [
      section(
        :manifest_paths,
        "artifacts/local-ble/<run-id>/release-candidate/manifests.md",
        :release_manifest_path_matrix,
        @manifest_paths,
        [
          "Attach generated readiness, release, JSON completion audit, plain-text completion audit, focused remaining-items audit, focused plain-text audit, AUX validation checklist, upstream maintainer handoff, blocker matrix, recent-evidence inventory, and advert-gossip audit paths."
        ],
        review.required_blocked_claims()
      ),
      section(
        :objective_review_paths,
        "artifacts/local-ble/<run-id>/release-candidate/objective-reviews.md",
        :objective_review_path_matrix,
        @review_paths,
        [
          "Attach persistence, lifecycle, iOS parity, full-resolution, known-good transport, multi-hop, routing, security, and UX review artifacts."
        ],
        review.required_blocked_claims()
      ),
      section(
        :hardware_attachments,
        "artifacts/local-ble/<run-id>/release-candidate/hardware/",
        :hardware_attachment_matrix,
        [
          :device_model,
          :os_or_api_version,
          :role,
          :command_or_harness,
          :summary_path,
          :raw_log_path,
          :gate_ids,
          :evidence_types_by_gate
        ],
        [
          "Attach concrete hardware logs for cited gates and call out every still-open hardware gate.",
          "Open gates currently required in release notes: #{Enum.join(open_gate_ids, ", ")}."
        ],
        review.required_blocked_claims()
      ),
      section(
        :operator_release_notes,
        "artifacts/local-ble/<run-id>/release-candidate/operator-notes.md",
        :operator_release_notes,
        [
          :notes_path,
          :allowed_wording,
          :blocked_claims_called_out,
          :open_hardware_gate_ids_called_out
        ],
        [
          "Use only the allowed nearby-message wording and explicitly call out blocked claims and open gates."
        ],
        review.required_blocked_claims()
      ),
      section(
        :candidate_review,
        "artifacts/local-ble/<run-id>/release-candidate/evidence.json",
        :release_candidate_review_input,
        [
          :artifact_path,
          :summary,
          :template_command,
          :review_command,
          :blocked_claims_called_out
        ],
        [
          "Run the release-candidate template command, complete it with operator evidence, then run the review command before accepting release notes."
        ],
        review.required_blocked_claims()
      )
    ]
  end

  defp section(id, artifact_path, evidence_type, required_entries, notes, blocked_claims) do
    %{
      id: id,
      artifact_path: artifact_path,
      evidence_type: evidence_type,
      required_entries: required_entries,
      blocked_claims_called_out: blocked_claims,
      notes: notes
    }
  end

  defp review_commands do
    [
      "mix meshx.mobile.local_release.candidate_review --template --out artifacts/local-ble/<run-id>/release-candidate/evidence.json",
      "mix meshx.mobile.local_release.candidate_review --input artifacts/local-ble/<run-id>/release-candidate/evidence.json --json --out tmp/local-release-candidate-review.json"
    ]
  end
end
