defmodule MeshxMobileApp.BLE.LocalInboxUxTargetDeviceScenarioPlan do
  @moduledoc """
  Target-device scenario plan for Nearby Messages UX evidence.

  The plan expands the operator capture checklist into concrete state,
  filter, sort, selected-detail, copy, and density scenarios. It is a pure
  evidence-planning artifact. It does not inspect screenshots, render UI,
  drive devices, scan, advertise, fetch, route, persist, ACK, retry, encrypt,
  authenticate, or run background work.
  """

  alias MeshxMobileApp.BLE.{LocalInboxStateCopy, LocalInboxUxEvidenceReview}

  @states LocalInboxUxEvidenceReview.required_states()
  @interactions LocalInboxUxEvidenceReview.required_interactions()
  @blocked_claims LocalInboxUxEvidenceReview.required_blocked_claims()
  @allowed_evidence_kinds LocalInboxUxEvidenceReview.allowed_evidence_kinds()

  @sort_scenarios [
    %{sort: :recent_first, expected_summary: "Newest observations first"},
    %{sort: :state_then_recent, expected_summary: "Full messages, refs, gossip, then stale"},
    %{sort: :strongest_rssi, expected_summary: "Strongest signal first"},
    %{sort: :payload_kind_then_recent, expected_summary: "Grouped by payload kind, then newest"},
    %{sort: :oldest_first, expected_summary: "Oldest observations first"}
  ]

  @spec snapshot() :: map()
  def snapshot do
    %{
      plan_version: 1,
      boundary: :nearby_messages_target_device_scenario_plan,
      status: :open,
      production_ux_claim_allowed?: false,
      delivery_claim_allowed?: false,
      trusted_delivery_claim_allowed?: false,
      routing_claim_allowed?: false,
      required_states: @states,
      required_interactions: @interactions,
      required_sorts: Enum.map(@sort_scenarios, & &1.sort),
      allowed_evidence_kinds: @allowed_evidence_kinds,
      required_blocked_claims: @blocked_claims,
      artifact_root: "artifacts/local-ble/<run-id>/ux/",
      target_device_setup: target_device_setup(),
      state_row_scenarios: state_row_scenarios(),
      filter_scenarios: filter_scenarios(),
      sort_scenarios: @sort_scenarios,
      selected_detail_scenarios: selected_detail_scenarios(),
      copy_review_scenarios: copy_review_scenarios(),
      visual_density_scenarios: visual_density_scenarios(),
      review_commands: review_commands(),
      notes: [
        "This scenario plan is not target-device evidence by itself.",
        "Every completed scenario must be supplied to LocalInboxUxEvidenceReview with evidence_kind screenshot or operator_note.",
        "Scenario coverage cannot claim delivery, trust, routing, background behavior, or production UX without operator-reviewed target-device artifacts."
      ]
    }
  end

  @spec json_snapshot() :: map()
  def json_snapshot do
    snapshot()
    |> JSON.encode!()
    |> JSON.decode!()
  end

  defp target_device_setup do
    %{
      review_section: :target_devices,
      artifact_path: "artifacts/local-ble/<run-id>/ux/targets.json",
      required_fields: [
        :device_id,
        :device_model,
        :os_or_api_version,
        :screen_size_class,
        :app_build_id,
        :evidence_path
      ],
      notes: [
        "Record target metadata before state, interaction, detail, copy, or density artifacts.",
        "Operator notes are allowed, but they must identify the target device and app build."
      ]
    }
  end

  defp state_row_scenarios do
    Enum.map(@states, fn state ->
      copy = LocalInboxStateCopy.for_state(state)

      %{
        id: :"#{state}_row",
        state: state,
        review_section: :state_evidence,
        artifact_path: "artifacts/local-ble/<run-id>/ux/states/#{state}.png",
        allowed_evidence_kinds: @allowed_evidence_kinds,
        required_visible_copy: [
          copy.label,
          copy.badge,
          copy.summary,
          copy.next_action
        ],
        blocked_claims_called_out: copy.blocked_claims,
        delivery_claim_allowed?: false
      }
    end)
  end

  defp filter_scenarios do
    [
      %{
        id: :filter_all,
        selected_state: :all,
        review_section: :interaction_evidence,
        interaction: :filter_change,
        artifact_path: "artifacts/local-ble/<run-id>/ux/interactions/filter-all.png",
        expected_summary: "Showing all nearby observations"
      }
      | Enum.map(@states, fn state ->
          copy = LocalInboxStateCopy.for_state(state)

          %{
            id: :"filter_#{state}",
            selected_state: state,
            review_section: :interaction_evidence,
            interaction: :filter_change,
            artifact_path: "artifacts/local-ble/<run-id>/ux/interactions/filter-#{state}.png",
            expected_summary: "Showing #{String.downcase(copy.label)} only",
            expected_empty_copy: copy.empty_label
          }
        end)
    ]
  end

  defp selected_detail_scenarios do
    Enum.map(@states, fn state ->
      copy = LocalInboxStateCopy.for_state(state)

      %{
        id: :"#{state}_detail",
        state: state,
        review_section: :selected_detail_evidence,
        interaction: :detail_panel,
        artifact_path: "artifacts/local-ble/<run-id>/ux/details/#{state}.png",
        allowed_evidence_kinds: @allowed_evidence_kinds,
        required_visible_copy: [
          copy.detail_title,
          copy.limitation,
          copy.next_action
        ],
        required_identifier_lines: identifier_lines(state),
        blocked_claims_called_out: copy.blocked_claims,
        delivery_claim_allowed?: false
      }
    end)
  end

  defp identifier_lines(:full_message), do: ["Message ID:", "Sender:"]
  defp identifier_lines(_state), do: ["Message hash:", "Sender hash:"]

  defp copy_review_scenarios do
    %{
      review_section: :copy_review,
      artifact_path: "artifacts/local-ble/<run-id>/ux/copy-review.md",
      allowed_wording: LocalInboxUxEvidenceReview.allowed_wording(),
      required_checks: [
        :warning_text_captured,
        :control_summaries_captured,
        :state_blocked_claim_copy_captured,
        :detail_panel_copy_captured,
        :blocked_claims_called_out
      ],
      required_blocked_claims: @blocked_claims,
      notes: [
        "Copy must use nearby, observed, ref, or seen wording.",
        "Copy must not say delivered, trusted, routed, background, acknowledged, retried, or fetched."
      ]
    }
  end

  defp visual_density_scenarios do
    %{
      review_section: :visual_density_review,
      artifact_path: "artifacts/local-ble/<run-id>/ux/visual-density.md",
      densest_fixture_artifact_path: "artifacts/local-ble/<run-id>/ux/visual-density-densest.png",
      densest_fixture_evidence_kind: :screenshot,
      required_checks: [
        :row_truncation_reviewed,
        :wrapping_reviewed,
        :tap_targets_reviewed,
        :detail_readability_reviewed,
        :densest_fixture_captured,
        :densest_fixture_artifact_path,
        :densest_fixture_evidence_kind
      ],
      target_profiles: [:small_or_older_android, :current_target],
      notes: [
        "Review the densest all-states fixture and every selected detail state.",
        "No critical row, warning, identifier, limitation, or next-action copy may disappear."
      ]
    }
  end

  defp review_commands do
    [
      "mix meshx.mobile.local_inbox.ux_review --template --out artifacts/local-ble/<run-id>/ux/evidence.json",
      "mix meshx.mobile.local_inbox.ux_review --input artifacts/local-ble/<run-id>/ux/evidence.json --json --out tmp/local-inbox-ux-review.json"
    ]
  end
end
