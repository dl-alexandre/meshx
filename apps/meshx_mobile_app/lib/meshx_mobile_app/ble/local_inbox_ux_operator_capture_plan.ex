defmodule MeshxMobileApp.BLE.LocalInboxUxOperatorCapturePlan do
  @moduledoc """
  Operator capture plan for Nearby Messages target-device UX evidence.

  The plan turns the open `LocalInboxUxValidationPlan` gates into concrete
  artifact slots that an operator can fill before running
  `LocalInboxUxEvidenceReview`. It does not inspect screenshots, render UI,
  drive devices, scan, advertise, fetch, route, persist, ACK, retry, encrypt,
  or run background work.
  """

  alias MeshxMobileApp.BLE.{LocalInboxUxEvidenceReview, LocalInboxUxValidationPlan}

  @states LocalInboxUxEvidenceReview.required_states()
  @interactions LocalInboxUxEvidenceReview.required_interactions()
  @blocked_claims LocalInboxUxEvidenceReview.required_blocked_claims()
  @allowed_evidence_kinds LocalInboxUxEvidenceReview.allowed_evidence_kinds()

  @spec snapshot() :: map()
  def snapshot do
    %{
      plan_version: 1,
      boundary: :nearby_messages_operator_capture_plan,
      status: :open,
      production_ux_claim_allowed?: false,
      delivery_claim_allowed?: false,
      trusted_delivery_claim_allowed?: false,
      routing_claim_allowed?: false,
      validation_plan: LocalInboxUxValidationPlan.snapshot(),
      allowed_evidence_kinds: @allowed_evidence_kinds,
      required_states: @states,
      required_interactions: @interactions,
      required_blocked_claims: @blocked_claims,
      capture_sections: capture_sections(),
      review_commands: review_commands(),
      expected_review_sections: expected_review_sections(),
      artifact_root: "artifacts/local-ble/<run-id>/ux/",
      notes: [
        "This plan is an operator capture checklist, not evidence by itself.",
        "Every artifact must be classified as screenshot or operator_note before review.",
        "Running the review command can make UX evidence ready, but still cannot claim delivery, trust, routing, or background behavior."
      ]
    }
  end

  @spec json_snapshot() :: map()
  def json_snapshot do
    snapshot()
    |> JSON.encode!()
    |> JSON.decode!()
  end

  defp capture_sections do
    [
      %{
        id: :target_devices,
        review_section: :target_devices,
        artifact_path: "artifacts/local-ble/<run-id>/ux/targets.json",
        required_entries: [
          "device_id",
          "device_model",
          "os_or_api_version",
          "screen_size_class",
          "app_build_id",
          "evidence_path"
        ],
        gate_ids: [:target_device_matrix],
        notes: [
          "Declare every target device before attaching state, interaction, copy, or density artifacts."
        ]
      },
      %{
        id: :state_evidence,
        review_section: :state_evidence,
        artifact_path: "artifacts/local-ble/<run-id>/ux/states/",
        required_entries:
          Enum.map(@states, fn state ->
            %{
              state: state,
              evidence_kind: @allowed_evidence_kinds,
              required_copy:
                "Row for #{state} is visible and distinct from other Nearby Messages states."
            }
          end),
        gate_ids: [:state_coverage_screenshots],
        notes: [
          "State evidence must cover full message, unresolved ref, gossiped ref, and stale ref rows."
        ]
      },
      %{
        id: :interaction_evidence,
        review_section: :interaction_evidence,
        artifact_path: "artifacts/local-ble/<run-id>/ux/interactions/",
        required_entries:
          Enum.map(@interactions, fn interaction ->
            %{
              interaction: interaction,
              evidence_kind: @allowed_evidence_kinds
            }
          end),
        gate_ids: [:interaction_coverage],
        notes: [
          "Interaction evidence must cover filters, sorting, row selection, and detail panels."
        ]
      },
      %{
        id: :selected_detail_evidence,
        review_section: :selected_detail_evidence,
        artifact_path: "artifacts/local-ble/<run-id>/ux/details/",
        required_entries:
          Enum.map(@states, fn state ->
            %{
              state: state,
              evidence_kind: @allowed_evidence_kinds,
              required_copy:
                "Selected detail for #{state} shows limitation, next action, identifiers, and blocked claims."
            }
          end),
        gate_ids: [:interaction_coverage, :blocked_claim_copy_review],
        notes: [
          "Selected detail evidence is separate from row/state screenshots."
        ]
      },
      %{
        id: :copy_review,
        review_section: :copy_review,
        artifact_path: "artifacts/local-ble/<run-id>/ux/copy-review.md",
        required_entries: [
          :warning_text_captured,
          :control_summaries_captured,
          :state_blocked_claim_copy_captured,
          :detail_panel_copy_captured,
          :allowed_wording,
          :blocked_claims_called_out
        ],
        required_blocked_claims: @blocked_claims,
        gate_ids: [:blocked_claim_copy_review],
        notes: [
          "Copy review must preserve nearby/observed/ref wording and block delivery, trusted delivery, routing, and background-operation claims."
        ]
      },
      %{
        id: :visual_density_review,
        review_section: :visual_density_review,
        artifact_path: "artifacts/local-ble/<run-id>/ux/visual-density.md",
        densest_fixture_artifact_path:
          "artifacts/local-ble/<run-id>/ux/visual-density-densest.png",
        densest_fixture_evidence_kind: :screenshot,
        required_entries: [
          :row_truncation_reviewed,
          :wrapping_reviewed,
          :tap_targets_reviewed,
          :detail_readability_reviewed,
          :densest_fixture_captured,
          :densest_fixture_artifact_path,
          :densest_fixture_evidence_kind
        ],
        gate_ids: [:visual_density_review],
        notes: [
          "Density review must cover row readability, warnings, tap targets, and detail panel readability on every declared target.",
          "The densest fixture screenshot artifact must be separate from the operator-note review artifact."
        ]
      }
    ]
  end

  defp review_commands do
    [
      "mix meshx.mobile.local_inbox.ux_review --template --out artifacts/local-ble/<run-id>/ux/evidence.json",
      "mix meshx.mobile.local_inbox.ux_review --input artifacts/local-ble/<run-id>/ux/evidence.json --json --out tmp/local-inbox-ux-review.json"
    ]
  end

  defp expected_review_sections do
    [
      :target_devices,
      :state_evidence,
      :interaction_evidence,
      :selected_detail_evidence,
      :copy_review,
      :visual_density_review
    ]
  end
end
