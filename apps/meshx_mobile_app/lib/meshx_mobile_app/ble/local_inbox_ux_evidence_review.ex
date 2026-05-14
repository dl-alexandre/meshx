defmodule MeshxMobileApp.BLE.LocalInboxUxEvidenceReview do
  @moduledoc """
  Pure review contract for Nearby Messages on-device UX evidence.

  This module validates the shape of operator-supplied UX evidence metadata
  for the `LocalInboxUxValidationPlan` gates. It does not read screenshots,
  render UI, drive devices, scan, advertise, fetch, route, persist, ACK,
  retry, encrypt, or run background work.
  """

  alias MeshxMobileApp.BLE.LocalInboxUxValidationPlan

  defmodule TargetDevice do
    @moduledoc false

    @derive {JSON.Encoder,
             only: [
               :device_id,
               :device_model,
               :os_or_api_version,
               :screen_size_class,
               :app_build_id,
               :evidence_path
             ]}
    @enforce_keys [
      :device_id,
      :device_model,
      :os_or_api_version,
      :screen_size_class,
      :app_build_id,
      :evidence_path
    ]
    defstruct @enforce_keys
  end

  defmodule StateEvidence do
    @moduledoc false

    @derive {JSON.Encoder,
             only: [:state, :target_device_id, :evidence_kind, :artifact_path, :notes]}
    @enforce_keys [:state, :target_device_id, :evidence_kind, :artifact_path, :notes]
    defstruct @enforce_keys
  end

  defmodule InteractionEvidence do
    @moduledoc false

    @derive {JSON.Encoder,
             only: [:interaction, :target_device_id, :evidence_kind, :artifact_path, :notes]}
    @enforce_keys [:interaction, :target_device_id, :evidence_kind, :artifact_path, :notes]
    defstruct @enforce_keys
  end

  defmodule SelectedDetailEvidence do
    @moduledoc false

    @derive {JSON.Encoder,
             only: [
               :state,
               :target_device_id,
               :evidence_kind,
               :artifact_path,
               :limitation_copy,
               :next_action_copy,
               :blocked_claim_copy,
               :notes
             ]}
    @enforce_keys [
      :state,
      :target_device_id,
      :evidence_kind,
      :artifact_path,
      :limitation_copy,
      :next_action_copy,
      :blocked_claim_copy,
      :notes
    ]
    defstruct @enforce_keys
  end

  defmodule CopyReview do
    @moduledoc false

    @derive {JSON.Encoder,
             only: [
               :review_path,
               :evidence_kind,
               :target_device_ids_reviewed,
               :allowed_wording,
               :blocked_claims_called_out,
               :warning_text_captured,
               :control_summaries_captured,
               :state_blocked_claim_copy_captured,
               :detail_panel_copy_captured
             ]}
    @enforce_keys [
      :review_path,
      :evidence_kind,
      :target_device_ids_reviewed,
      :target_device_ids_reviewed_container_valid?,
      :target_device_ids_reviewed_present?,
      :allowed_wording,
      :blocked_claims_called_out,
      :blocked_claims_called_out_container_valid?,
      :blocked_claims_called_out_present?,
      :warning_text_captured,
      :warning_text_captured_present?,
      :control_summaries_captured,
      :control_summaries_captured_present?,
      :state_blocked_claim_copy_captured,
      :state_blocked_claim_copy_captured_present?,
      :detail_panel_copy_captured,
      :detail_panel_copy_captured_present?
    ]
    defstruct @enforce_keys
  end

  defmodule VisualDensityReview do
    @moduledoc false

    @derive {JSON.Encoder,
             only: [
               :artifact_path,
               :evidence_kind,
               :densest_fixture_artifact_path,
               :densest_fixture_evidence_kind,
               :target_device_ids_reviewed,
               :row_truncation_reviewed,
               :wrapping_reviewed,
               :tap_targets_reviewed,
               :detail_readability_reviewed,
               :densest_fixture_captured
             ]}
    @enforce_keys [
      :artifact_path,
      :evidence_kind,
      :densest_fixture_artifact_path,
      :densest_fixture_evidence_kind,
      :target_device_ids_reviewed,
      :target_device_ids_reviewed_container_valid?,
      :target_device_ids_reviewed_present?,
      :row_truncation_reviewed,
      :wrapping_reviewed,
      :tap_targets_reviewed,
      :detail_readability_reviewed,
      :densest_fixture_captured,
      :row_truncation_reviewed_present?,
      :wrapping_reviewed_present?,
      :tap_targets_reviewed_present?,
      :detail_readability_reviewed_present?,
      :densest_fixture_captured_present?
    ]
    defstruct @enforce_keys
  end

  @allowed_wording "Nearby Messages shows messages and beacon refs seen nearby from BLE advertisements."

  @required_states [:full_message, :unresolved_ref, :gossiped_ref, :stale_ref]
  @required_interactions [:filter_change, :sort_change, :row_selection, :detail_panel]
  @required_blocked_claims [:delivery, :trusted_delivery, :routing, :background_operation]
  @allowed_evidence_kinds [:screenshot, :operator_note]

  @spec allowed_wording() :: binary()
  def allowed_wording, do: @allowed_wording

  @spec required_states() :: [atom()]
  def required_states, do: @required_states

  @spec required_interactions() :: [atom()]
  def required_interactions, do: @required_interactions

  @spec required_blocked_claims() :: [atom()]
  def required_blocked_claims, do: @required_blocked_claims

  @spec allowed_evidence_kinds() :: [atom()]
  def allowed_evidence_kinds, do: @allowed_evidence_kinds

  @spec review(term()) :: map()
  def review(input) when is_map(input) do
    target_devices_input = get_field(input, :target_devices, [])
    state_evidence_input = get_field(input, :state_evidence, [])
    interaction_evidence_input = get_field(input, :interaction_evidence, [])
    selected_detail_evidence_input = get_field(input, :selected_detail_evidence, [])
    copy_review_input = get_field(input, :copy_review, %{})
    visual_density_review_input = get_field(input, :visual_density_review, %{})

    target_devices =
      target_devices_input
      |> list_value()
      |> Enum.map(&target_device/1)

    state_evidence =
      state_evidence_input
      |> list_value()
      |> Enum.map(&state_evidence/1)

    interaction_evidence =
      interaction_evidence_input
      |> list_value()
      |> Enum.map(&interaction_evidence/1)

    selected_detail_evidence =
      selected_detail_evidence_input
      |> list_value()
      |> Enum.map(&selected_detail_evidence/1)

    copy_review =
      copy_review_input
      |> copy_review()

    visual_density_review =
      visual_density_review_input
      |> visual_density_review()

    target_device_ids = target_device_ids(target_devices)

    missing =
      []
      |> missing_top_level_sections(input)
      |> malformed_top_level_containers(
        target_devices_input,
        state_evidence_input,
        interaction_evidence_input,
        selected_detail_evidence_input,
        copy_review_input,
        visual_density_review_input
      )
      |> malformed_evidence_rows(target_devices_input, "Target device")
      |> malformed_evidence_rows(state_evidence_input, "State evidence")
      |> malformed_evidence_rows(interaction_evidence_input, "Interaction evidence")
      |> malformed_evidence_rows(selected_detail_evidence_input, "Selected detail evidence")
      |> missing_target_devices(target_devices)
      |> duplicate_target_device_ids(target_devices)
      |> duplicate_target_device_evidence_paths(target_devices)
      |> missing_state_evidence(state_evidence, target_device_ids)
      |> unsupported_evidence_values(state_evidence, "State evidence", :state, @required_states)
      |> duplicate_evidence_coverage(state_evidence, "State evidence", :state)
      |> non_trimmed_paths(state_evidence, "State evidence", :artifact_path)
      |> non_relative_paths(state_evidence, "State evidence", :artifact_path)
      |> duplicate_artifact_paths(state_evidence, "State evidence")
      |> missing_interaction_evidence(interaction_evidence, target_device_ids)
      |> unsupported_evidence_values(
        interaction_evidence,
        "Interaction evidence",
        :interaction,
        @required_interactions
      )
      |> duplicate_evidence_coverage(interaction_evidence, "Interaction evidence", :interaction)
      |> non_trimmed_paths(interaction_evidence, "Interaction evidence", :artifact_path)
      |> non_relative_paths(interaction_evidence, "Interaction evidence", :artifact_path)
      |> duplicate_artifact_paths(interaction_evidence, "Interaction evidence")
      |> duplicate_state_interaction_artifact_paths(state_evidence, interaction_evidence)
      |> missing_selected_detail_evidence(selected_detail_evidence, target_device_ids)
      |> unsupported_evidence_values(
        selected_detail_evidence,
        "Selected detail evidence",
        :state,
        @required_states
      )
      |> duplicate_evidence_coverage(selected_detail_evidence, "Selected detail evidence", :state)
      |> non_trimmed_paths(selected_detail_evidence, "Selected detail evidence", :artifact_path)
      |> non_relative_paths(selected_detail_evidence, "Selected detail evidence", :artifact_path)
      |> duplicate_artifact_paths(selected_detail_evidence, "Selected detail evidence")
      |> duplicate_detail_evidence_artifact_paths(
        state_evidence,
        interaction_evidence,
        selected_detail_evidence
      )
      |> missing_target_device_evidence(
        target_device_ids,
        state_evidence,
        interaction_evidence,
        selected_detail_evidence
      )
      |> missing_copy_review(copy_review, target_device_ids)
      |> missing_visual_density_review(visual_density_review, target_device_ids)
      |> duplicate_review_artifact_paths(copy_review, visual_density_review)
      |> duplicate_review_evidence_artifact_paths(
        copy_review,
        visual_density_review,
        state_evidence,
        interaction_evidence,
        selected_detail_evidence
      )
      |> Enum.reverse()

    %{
      review_version: 1,
      boundary: :nearby_messages_on_device_ux_evidence,
      status: if(missing == [], do: :ready, else: :open),
      on_device_ux_evidence_complete?: missing == [],
      production_ux_claim_allowed?: false,
      delivery_claim_allowed?: false,
      trusted_delivery_claim_allowed?: false,
      routing_claim_allowed?: false,
      validation_plan: LocalInboxUxValidationPlan.snapshot(),
      required_states: @required_states,
      required_interactions: @required_interactions,
      required_blocked_claims: @required_blocked_claims,
      allowed_wording: @allowed_wording,
      target_devices: target_devices,
      state_evidence: state_evidence,
      interaction_evidence: interaction_evidence,
      selected_detail_evidence: selected_detail_evidence,
      copy_review: copy_review,
      visual_density_review: visual_density_review,
      coverage_summary:
        coverage_summary(
          target_devices,
          state_evidence,
          interaction_evidence,
          selected_detail_evidence,
          copy_review,
          visual_density_review
        ),
      missing: missing,
      notes: [
        "Ready evidence means the operator-supplied UX metadata covers LocalInboxUxValidationPlan gates.",
        "This review does not inspect screenshot pixels or turn Nearby Messages into delivery evidence.",
        "Delivery, trusted delivery, routing, persistence, and background claims remain blocked."
      ]
    }
  end

  def review(_input), do: review(%{})

  @spec json_review(term()) :: map()
  def json_review(input) do
    input
    |> review()
    |> JSON.encode!()
    |> JSON.decode!()
  end

  @spec template_input() :: map()
  def template_input do
    %{
      "target_devices" => [
        %{
          "device_id" => "",
          "device_model" => "",
          "os_or_api_version" => "",
          "screen_size_class" => "",
          "app_build_id" => "",
          "evidence_path" => ""
        }
      ],
      "state_evidence" =>
        Enum.map(@required_states, fn state ->
          %{
            "state" => Atom.to_string(state),
            "target_device_id" => "",
            "evidence_kind" => "",
            "artifact_path" => "",
            "notes" => ""
          }
        end),
      "interaction_evidence" =>
        Enum.map(@required_interactions, fn interaction ->
          %{
            "interaction" => Atom.to_string(interaction),
            "target_device_id" => "",
            "evidence_kind" => "",
            "artifact_path" => "",
            "notes" => ""
          }
        end),
      "selected_detail_evidence" =>
        Enum.map(@required_states, fn state ->
          %{
            "state" => Atom.to_string(state),
            "target_device_id" => "",
            "evidence_kind" => "",
            "artifact_path" => "",
            "limitation_copy" => "",
            "next_action_copy" => "",
            "blocked_claim_copy" => "",
            "notes" => ""
          }
        end),
      "copy_review" => %{
        "review_path" => "",
        "evidence_kind" => "",
        "target_device_ids_reviewed" => [],
        "allowed_wording" => @allowed_wording,
        "blocked_claims_called_out" => [],
        "warning_text_captured" => false,
        "control_summaries_captured" => false,
        "state_blocked_claim_copy_captured" => false,
        "detail_panel_copy_captured" => false
      },
      "visual_density_review" => %{
        "artifact_path" => "",
        "evidence_kind" => "",
        "densest_fixture_artifact_path" => "",
        "densest_fixture_evidence_kind" => "",
        "target_device_ids_reviewed" => [],
        "row_truncation_reviewed" => false,
        "wrapping_reviewed" => false,
        "tap_targets_reviewed" => false,
        "detail_readability_reviewed" => false,
        "densest_fixture_captured" => false
      }
    }
  end

  defp missing_top_level_sections(missing, input) do
    missing
    |> missing_top_level_section(input, :target_devices)
    |> missing_top_level_section(input, :state_evidence)
    |> missing_top_level_section(input, :interaction_evidence)
    |> missing_top_level_section(input, :selected_detail_evidence)
    |> missing_top_level_section(input, :copy_review)
    |> missing_top_level_section(input, :visual_density_review)
  end

  defp missing_top_level_section(missing, input, field) do
    if has_field?(input, field) do
      missing
    else
      ["Missing #{field} section." | missing]
    end
  end

  defp malformed_top_level_containers(
         missing,
         target_devices_input,
         state_evidence_input,
         interaction_evidence_input,
         selected_detail_evidence_input,
         copy_review_input,
         visual_density_review_input
       ) do
    missing
    |> maybe_missing(is_list(target_devices_input), "target_devices must be a list.")
    |> maybe_missing(is_list(state_evidence_input), "state_evidence must be a list.")
    |> maybe_missing(
      is_list(interaction_evidence_input),
      "interaction_evidence must be a list."
    )
    |> maybe_missing(
      is_list(selected_detail_evidence_input),
      "selected_detail_evidence must be a list."
    )
    |> maybe_missing(is_map(copy_review_input), "copy_review must be an object.")
    |> maybe_missing(
      is_map(visual_density_review_input),
      "visual_density_review must be an object."
    )
  end

  defp malformed_evidence_rows(missing, values, label) when is_list(values) do
    values
    |> Enum.with_index(1)
    |> Enum.reduce(missing, fn {value, index}, acc ->
      if is_map(value) do
        acc
      else
        ["#{label} #{index} must be an object." | acc]
      end
    end)
  end

  defp malformed_evidence_rows(missing, _values, _label), do: missing

  defp missing_target_devices(missing, []),
    do: ["Missing at least one target device." | missing]

  defp missing_target_devices(missing, devices) do
    devices
    |> Enum.with_index(1)
    |> Enum.reduce(missing, fn {device, index}, acc ->
      []
      |> missing_field(device, index, "Target device", :device_id)
      |> missing_field(device, index, "Target device", :device_model)
      |> missing_field(device, index, "Target device", :os_or_api_version)
      |> missing_field(device, index, "Target device", :screen_size_class)
      |> missing_field(device, index, "Target device", :app_build_id)
      |> missing_field(device, index, "Target device", :evidence_path)
      |> non_trimmed_identity(device.device_id, "Target device #{index}", :device_id)
      |> malformed_string_field(device.device_id, "Target device #{index}", :device_id)
      |> malformed_string_field(device.device_model, "Target device #{index}", :device_model)
      |> malformed_string_field(
        device.os_or_api_version,
        "Target device #{index}",
        :os_or_api_version
      )
      |> malformed_string_field(
        device.screen_size_class,
        "Target device #{index}",
        :screen_size_class
      )
      |> malformed_string_field(device.app_build_id, "Target device #{index}", :app_build_id)
      |> malformed_string_field(device.evidence_path, "Target device #{index}", :evidence_path)
      |> non_trimmed_text(device.device_model, "Target device #{index}", :device_model)
      |> non_trimmed_text(
        device.os_or_api_version,
        "Target device #{index}",
        :os_or_api_version
      )
      |> non_trimmed_text(
        device.screen_size_class,
        "Target device #{index}",
        :screen_size_class
      )
      |> non_trimmed_text(device.app_build_id, "Target device #{index}", :app_build_id)
      |> non_trimmed_path(device.evidence_path, "Target device #{index}", :evidence_path)
      |> non_relative_path(device.evidence_path, "Target device #{index}", :evidence_path)
      |> Kernel.++(acc)
    end)
  end

  defp duplicate_target_device_ids(missing, devices) do
    duplicate_ids =
      devices
      |> Enum.map(& &1.device_id)
      |> Enum.filter(&present?/1)
      |> Enum.frequencies()
      |> Enum.filter(fn {_device_id, count} -> count > 1 end)
      |> Enum.map(fn {device_id, _count} -> device_id end)
      |> Enum.sort()

    if duplicate_ids == [] do
      missing
    else
      ["Duplicate target device ids: #{inspect(duplicate_ids)}." | missing]
    end
  end

  defp duplicate_target_device_evidence_paths(missing, devices) do
    duplicate_paths =
      devices
      |> Enum.map(& &1.evidence_path)
      |> Enum.filter(&present?/1)
      |> Enum.frequencies()
      |> Enum.filter(fn {_evidence_path, count} -> count > 1 end)
      |> Enum.map(fn {evidence_path, _count} -> evidence_path end)
      |> Enum.sort()

    if duplicate_paths == [] do
      missing
    else
      ["Duplicate target device evidence paths: #{inspect(duplicate_paths)}." | missing]
    end
  end

  defp duplicate_artifact_paths(missing, evidence, label) do
    duplicate_paths =
      evidence
      |> Enum.map(& &1.artifact_path)
      |> Enum.filter(&present?/1)
      |> Enum.frequencies()
      |> Enum.filter(fn {_artifact_path, count} -> count > 1 end)
      |> Enum.map(fn {artifact_path, _count} -> artifact_path end)
      |> Enum.sort()

    if duplicate_paths == [] do
      missing
    else
      ["#{label} has duplicate artifact paths: #{inspect(duplicate_paths)}." | missing]
    end
  end

  defp duplicate_state_interaction_artifact_paths(missing, state_evidence, interaction_evidence) do
    state_paths = artifact_path_set(state_evidence)
    interaction_paths = artifact_path_set(interaction_evidence)

    duplicate_paths =
      state_paths
      |> MapSet.intersection(interaction_paths)
      |> MapSet.to_list()
      |> Enum.sort()

    if duplicate_paths == [] do
      missing
    else
      [
        "State and interaction evidence share artifact paths: #{inspect(duplicate_paths)}."
        | missing
      ]
    end
  end

  defp duplicate_detail_evidence_artifact_paths(
         missing,
         state_evidence,
         interaction_evidence,
         selected_detail_evidence
       ) do
    existing_paths =
      state_evidence
      |> artifact_path_set()
      |> MapSet.union(artifact_path_set(interaction_evidence))

    duplicate_paths =
      selected_detail_evidence
      |> artifact_path_set()
      |> MapSet.intersection(existing_paths)
      |> MapSet.to_list()
      |> Enum.sort()

    if duplicate_paths == [] do
      missing
    else
      [
        "Selected detail evidence reuses state or interaction evidence paths: #{inspect(duplicate_paths)}."
        | missing
      ]
    end
  end

  defp artifact_path_set(evidence) do
    evidence
    |> Enum.map(& &1.artifact_path)
    |> Enum.filter(&present?/1)
    |> MapSet.new()
  end

  defp duplicate_evidence_coverage(missing, evidence, label, evidence_field) do
    duplicate_pairs =
      evidence
      |> Enum.map(&{&1.target_device_id, Map.fetch!(&1, evidence_field)})
      |> Enum.filter(fn {target_device_id, value} ->
        present?(target_device_id) and present?(value)
      end)
      |> Enum.frequencies()
      |> Enum.filter(fn {_pair, count} -> count > 1 end)
      |> Enum.map(fn {pair, _count} -> pair end)
      |> Enum.sort()

    if duplicate_pairs == [] do
      missing
    else
      ["#{label} has duplicate target coverage: #{inspect(duplicate_pairs)}." | missing]
    end
  end

  defp unsupported_evidence_values(missing, evidence, label, evidence_field, allowed_values) do
    unsupported_values =
      evidence
      |> Enum.map(&Map.fetch!(&1, evidence_field))
      |> Enum.filter(&present?/1)
      |> Enum.reject(&(&1 in allowed_values))
      # Display as strings: atom_value/1 atomizes a value only when its atom
      # already exists, so the raw values are an unpredictable atom/string mix.
      |> Enum.map(&to_string/1)
      |> Enum.uniq()
      |> Enum.sort()

    if unsupported_values == [] do
      missing
    else
      [
        "#{label} has unsupported #{evidence_field} values: #{inspect(unsupported_values)}."
        | missing
      ]
    end
  end

  defp missing_state_evidence(missing, evidence, target_device_ids) do
    states = Enum.map(evidence, & &1.state)
    missing_states = @required_states -- states

    missing =
      if missing_states == [] do
        missing
      else
        ["Missing state evidence for: #{inspect(missing_states)}." | missing]
      end

    evidence
    |> Enum.with_index(1)
    |> Enum.reduce(missing, fn {item, index}, acc ->
      []
      |> missing_field(item, index, "State evidence", :state)
      |> missing_field(item, index, "State evidence", :target_device_id)
      |> missing_field(item, index, "State evidence", :evidence_kind)
      |> missing_field(item, index, "State evidence", :artifact_path)
      |> missing_field(item, index, "State evidence", :notes)
      |> non_trimmed_identity(item.target_device_id, "State evidence #{index}", :target_device_id)
      |> malformed_enum_field(item.state, "State evidence #{index}", :state)
      |> malformed_enum_field(item.evidence_kind, "State evidence #{index}", :evidence_kind)
      |> non_trimmed_enum(item.state, "State evidence #{index}", :state)
      |> non_trimmed_enum(item.evidence_kind, "State evidence #{index}", :evidence_kind)
      |> malformed_string_field(
        item.target_device_id,
        "State evidence #{index}",
        :target_device_id
      )
      |> malformed_string_field(item.artifact_path, "State evidence #{index}", :artifact_path)
      |> malformed_string_field(item.notes, "State evidence #{index}", :notes)
      |> non_trimmed_text(item.notes, "State evidence #{index}", :notes)
      |> invalid_evidence_kind(item, index, "State evidence")
      |> missing_declared_target_device(
        item.target_device_id,
        target_device_ids,
        "State evidence",
        index
      )
      |> Kernel.++(acc)
    end)
  end

  defp missing_interaction_evidence(missing, evidence, target_device_ids) do
    interactions = Enum.map(evidence, & &1.interaction)
    missing_interactions = @required_interactions -- interactions

    missing =
      if missing_interactions == [] do
        missing
      else
        ["Missing interaction evidence for: #{inspect(missing_interactions)}." | missing]
      end

    evidence
    |> Enum.with_index(1)
    |> Enum.reduce(missing, fn {item, index}, acc ->
      []
      |> missing_field(item, index, "Interaction evidence", :interaction)
      |> missing_field(item, index, "Interaction evidence", :target_device_id)
      |> missing_field(item, index, "Interaction evidence", :evidence_kind)
      |> missing_field(item, index, "Interaction evidence", :artifact_path)
      |> missing_field(item, index, "Interaction evidence", :notes)
      |> malformed_enum_field(item.interaction, "Interaction evidence #{index}", :interaction)
      |> malformed_enum_field(item.evidence_kind, "Interaction evidence #{index}", :evidence_kind)
      |> non_trimmed_enum(item.interaction, "Interaction evidence #{index}", :interaction)
      |> non_trimmed_enum(item.evidence_kind, "Interaction evidence #{index}", :evidence_kind)
      |> non_trimmed_identity(
        item.target_device_id,
        "Interaction evidence #{index}",
        :target_device_id
      )
      |> malformed_string_field(
        item.target_device_id,
        "Interaction evidence #{index}",
        :target_device_id
      )
      |> malformed_string_field(
        item.artifact_path,
        "Interaction evidence #{index}",
        :artifact_path
      )
      |> malformed_string_field(item.notes, "Interaction evidence #{index}", :notes)
      |> non_trimmed_text(item.notes, "Interaction evidence #{index}", :notes)
      |> invalid_evidence_kind(item, index, "Interaction evidence")
      |> missing_declared_target_device(
        item.target_device_id,
        target_device_ids,
        "Interaction evidence",
        index
      )
      |> Kernel.++(acc)
    end)
  end

  defp missing_selected_detail_evidence(missing, evidence, target_device_ids) do
    states = Enum.map(evidence, & &1.state)
    missing_states = @required_states -- states

    missing =
      if missing_states == [] do
        missing
      else
        ["Missing selected detail evidence for: #{inspect(missing_states)}." | missing]
      end

    evidence
    |> Enum.with_index(1)
    |> Enum.reduce(missing, fn {item, index}, acc ->
      []
      |> missing_field(item, index, "Selected detail evidence", :state)
      |> missing_field(item, index, "Selected detail evidence", :target_device_id)
      |> missing_field(item, index, "Selected detail evidence", :evidence_kind)
      |> missing_field(item, index, "Selected detail evidence", :artifact_path)
      |> missing_field(item, index, "Selected detail evidence", :limitation_copy)
      |> missing_field(item, index, "Selected detail evidence", :next_action_copy)
      |> missing_field(item, index, "Selected detail evidence", :blocked_claim_copy)
      |> missing_field(item, index, "Selected detail evidence", :notes)
      |> malformed_enum_field(item.state, "Selected detail evidence #{index}", :state)
      |> malformed_enum_field(
        item.evidence_kind,
        "Selected detail evidence #{index}",
        :evidence_kind
      )
      |> non_trimmed_enum(item.state, "Selected detail evidence #{index}", :state)
      |> non_trimmed_enum(
        item.evidence_kind,
        "Selected detail evidence #{index}",
        :evidence_kind
      )
      |> non_trimmed_identity(
        item.target_device_id,
        "Selected detail evidence #{index}",
        :target_device_id
      )
      |> malformed_string_field(
        item.target_device_id,
        "Selected detail evidence #{index}",
        :target_device_id
      )
      |> malformed_string_field(
        item.artifact_path,
        "Selected detail evidence #{index}",
        :artifact_path
      )
      |> malformed_string_field(
        item.limitation_copy,
        "Selected detail evidence #{index}",
        :limitation_copy
      )
      |> malformed_string_field(
        item.next_action_copy,
        "Selected detail evidence #{index}",
        :next_action_copy
      )
      |> malformed_string_field(
        item.blocked_claim_copy,
        "Selected detail evidence #{index}",
        :blocked_claim_copy
      )
      |> non_trimmed_text(
        item.limitation_copy,
        "Selected detail evidence #{index}",
        :limitation_copy
      )
      |> non_trimmed_text(
        item.next_action_copy,
        "Selected detail evidence #{index}",
        :next_action_copy
      )
      |> non_trimmed_text(
        item.blocked_claim_copy,
        "Selected detail evidence #{index}",
        :blocked_claim_copy
      )
      |> malformed_string_field(item.notes, "Selected detail evidence #{index}", :notes)
      |> non_trimmed_text(item.notes, "Selected detail evidence #{index}", :notes)
      |> invalid_evidence_kind(item, index, "Selected detail evidence")
      |> missing_declared_target_device(
        item.target_device_id,
        target_device_ids,
        "Selected detail evidence",
        index
      )
      |> Kernel.++(acc)
    end)
  end

  defp missing_target_device_evidence(
         missing,
         target_device_ids,
         state_evidence,
         interaction_evidence,
         selected_detail_evidence
       ) do
    state_coverage = evidence_coverage(state_evidence, :state)
    interaction_coverage = evidence_coverage(interaction_evidence, :interaction)
    selected_detail_coverage = evidence_coverage(selected_detail_evidence, :state)

    target_device_ids
    |> Enum.sort()
    |> Enum.reduce(missing, fn device_id, acc ->
      acc
      |> missing_target_device_states(device_id, state_coverage)
      |> missing_target_device_interactions(device_id, interaction_coverage)
      |> missing_target_device_selected_details(device_id, selected_detail_coverage)
    end)
  end

  defp missing_target_device_states(missing, device_id, coverage) do
    missing_states =
      Enum.reject(@required_states, &MapSet.member?(coverage, {device_id, &1}))

    if missing_states == [] do
      missing
    else
      [
        "Target device #{inspect(device_id)} missing state evidence for: #{inspect(missing_states)}."
        | missing
      ]
    end
  end

  defp missing_target_device_interactions(missing, device_id, coverage) do
    missing_interactions =
      Enum.reject(@required_interactions, &MapSet.member?(coverage, {device_id, &1}))

    if missing_interactions == [] do
      missing
    else
      [
        "Target device #{inspect(device_id)} missing interaction evidence for: #{inspect(missing_interactions)}."
        | missing
      ]
    end
  end

  defp missing_target_device_selected_details(missing, device_id, coverage) do
    missing_states =
      Enum.reject(@required_states, &MapSet.member?(coverage, {device_id, &1}))

    if missing_states == [] do
      missing
    else
      [
        "Target device #{inspect(device_id)} missing selected detail evidence for: #{inspect(missing_states)}."
        | missing
      ]
    end
  end

  defp evidence_coverage(evidence, evidence_field) do
    evidence
    |> Enum.map(&{&1.target_device_id, Map.fetch!(&1, evidence_field)})
    |> Enum.filter(fn {target_device_id, value} ->
      present?(target_device_id) and present?(value)
    end)
    |> MapSet.new()
  end

  defp coverage_summary(
         target_devices,
         state_evidence,
         interaction_evidence,
         selected_detail_evidence,
         copy_review,
         visual_density_review
       ) do
    target_device_ids = target_device_ids(target_devices)
    state_coverage = evidence_coverage(state_evidence, :state)
    interaction_coverage = evidence_coverage(interaction_evidence, :interaction)
    selected_detail_coverage = evidence_coverage(selected_detail_evidence, :state)
    selected_detail_copy_anchor_coverage =
      selected_detail_evidence
      |> Enum.filter(&selected_detail_copy_anchors_present?/1)
      |> evidence_coverage(:state)

    %{
      target_device_count: MapSet.size(target_device_ids),
      state_evidence_count: length(state_evidence),
      interaction_evidence_count: length(interaction_evidence),
      selected_detail_evidence_count: length(selected_detail_evidence),
      required_state_count: length(@required_states),
      required_interaction_count: length(@required_interactions),
      copy_review_target_count: reviewed_target_count(copy_review),
      visual_density_target_count: reviewed_target_count(visual_density_review),
      all_target_devices_have_state_coverage?:
        all_targets_have_coverage?(target_device_ids, state_coverage, @required_states),
      all_target_devices_have_interaction_coverage?:
        all_targets_have_coverage?(
          target_device_ids,
          interaction_coverage,
          @required_interactions
        ),
      all_target_devices_have_selected_detail_coverage?:
        all_targets_have_coverage?(target_device_ids, selected_detail_coverage, @required_states),
      all_target_devices_have_selected_detail_copy_anchors?:
        all_targets_have_coverage?(
          target_device_ids,
          selected_detail_copy_anchor_coverage,
          @required_states
        ),
      all_target_devices_copy_reviewed?:
        target_device_ids_covered?(target_device_ids, copy_review.target_device_ids_reviewed),
      all_target_devices_density_reviewed?:
        target_device_ids_covered?(
          target_device_ids,
          visual_density_review.target_device_ids_reviewed
        )
    }
  end

  defp selected_detail_copy_anchors_present?(evidence) do
    present?(evidence.limitation_copy) and present?(evidence.next_action_copy) and
      present?(evidence.blocked_claim_copy)
  end

  defp reviewed_target_count(review) do
    review.target_device_ids_reviewed
    |> Enum.filter(&present?/1)
    |> Enum.uniq()
    |> length()
  end

  defp all_targets_have_coverage?(target_device_ids, coverage, required_values) do
    MapSet.size(target_device_ids) > 0 and
      Enum.all?(target_device_ids, fn device_id ->
        Enum.all?(required_values, &MapSet.member?(coverage, {device_id, &1}))
      end)
  end

  defp target_device_ids_covered?(target_device_ids, reviewed_ids) do
    MapSet.size(target_device_ids) > 0 and
      MapSet.subset?(target_device_ids, MapSet.new(reviewed_ids))
  end

  defp target_device_ids(devices) do
    devices
    |> Enum.map(& &1.device_id)
    |> Enum.filter(&present?/1)
    |> MapSet.new()
  end

  defp missing_declared_target_device(missing, target_device_id, target_device_ids, label, index) do
    cond do
      not present?(target_device_id) ->
        missing

      MapSet.member?(target_device_ids, target_device_id) ->
        missing

      true ->
        [
          "#{label} #{index} references undeclared target_device_id #{inspect(target_device_id)}."
          | missing
        ]
    end
  end

  defp missing_copy_review(missing, review, target_device_ids) do
    missing_claims = @required_blocked_claims -- review.blocked_claims_called_out
    unsupported_claims = unsupported_blocked_claims(review)
    duplicate_claims = duplicate_blocked_claims(review)
    malformed_claims = malformed_blocked_claims(review)
    non_trimmed_claims = non_trimmed_blocked_claims(review)
    missing_target_device_ids = missing_review_target_device_ids(target_device_ids, review)
    undeclared_target_device_ids = undeclared_review_target_device_ids(target_device_ids, review)
    duplicate_target_device_ids = duplicate_review_target_device_ids(review)
    non_trimmed_target_device_ids = non_trimmed_review_target_device_ids(review)
    malformed_target_device_ids = malformed_review_target_device_ids(review)
    target_device_ids_container_valid? = review_target_device_ids_container_valid?(review)
    blocked_claims_container_valid? = review_blocked_claims_container_valid?(review)

    missing
    |> missing_review_field(review, "Copy review", :review_path)
    |> malformed_string_field(review.review_path, "Copy review", :review_path)
    |> non_trimmed_path(review.review_path, "Copy review", :review_path)
    |> non_relative_path(review.review_path, "Copy review", :review_path)
    |> missing_review_field(review, "Copy review", :evidence_kind)
    |> malformed_enum_field(review.evidence_kind, "Copy review", :evidence_kind)
    |> non_trimmed_enum(review.evidence_kind, "Copy review", :evidence_kind)
    |> invalid_evidence_kind(review, nil, "Copy review")
    |> missing_list_review_field(review, "Copy review", :target_device_ids_reviewed)
    |> maybe_missing(
      target_device_ids_container_valid?,
      "Copy review target_device_ids_reviewed must be a list."
    )
    |> maybe_missing(
      malformed_target_device_ids == [],
      "Copy review target_device_ids_reviewed must contain only non-empty strings: #{inspect(malformed_target_device_ids)}."
    )
    |> maybe_missing(
      non_trimmed_target_device_ids == [],
      "Copy review target_device_ids_reviewed must not contain ids with leading or trailing whitespace: #{inspect(non_trimmed_target_device_ids)}."
    )
    |> maybe_missing(
      duplicate_target_device_ids == [],
      "Copy review has duplicate reviewed target devices: #{inspect(duplicate_target_device_ids)}."
    )
    |> maybe_missing(
      missing_target_device_ids == [],
      "Copy review missing target devices: #{inspect(missing_target_device_ids)}."
    )
    |> maybe_missing(
      undeclared_target_device_ids == [],
      "Copy review references undeclared target devices: #{inspect(undeclared_target_device_ids)}."
    )
    |> missing_review_field(review, "Copy review", :allowed_wording)
    |> malformed_string_field(review.allowed_wording, "Copy review", :allowed_wording)
    |> non_trimmed_text(review.allowed_wording, "Copy review", :allowed_wording)
    |> missing_allowed_wording(review)
    |> missing_list_review_field(review, "Copy review", :blocked_claims_called_out)
    |> maybe_missing(
      blocked_claims_container_valid?,
      "Copy review blocked_claims_called_out must be a list."
    )
    |> maybe_missing(
      malformed_claims == [],
      "Copy review blocked_claims_called_out must contain only non-empty strings or atoms: #{inspect(malformed_claims)}."
    )
    |> maybe_missing(
      non_trimmed_claims == [],
      "Copy review blocked_claims_called_out must not contain claims with leading or trailing whitespace: #{inspect(non_trimmed_claims)}."
    )
    |> missing_boolean_review_field(review, "Copy review", :warning_text_captured)
    |> malformed_boolean_field(
      review.warning_text_captured,
      "Copy review",
      :warning_text_captured
    )
    |> maybe_missing(
      review.warning_text_captured == true,
      "Copy review must capture visible warning or limitation text."
    )
    |> missing_boolean_review_field(review, "Copy review", :control_summaries_captured)
    |> malformed_boolean_field(
      review.control_summaries_captured,
      "Copy review",
      :control_summaries_captured
    )
    |> maybe_missing(
      review.control_summaries_captured == true,
      "Copy review must capture filter and sort control summaries."
    )
    |> missing_boolean_review_field(review, "Copy review", :state_blocked_claim_copy_captured)
    |> malformed_boolean_field(
      review.state_blocked_claim_copy_captured,
      "Copy review",
      :state_blocked_claim_copy_captured
    )
    |> maybe_missing(
      review.state_blocked_claim_copy_captured == true,
      "Copy review must capture per-state blocked-claim copy."
    )
    |> missing_boolean_review_field(review, "Copy review", :detail_panel_copy_captured)
    |> malformed_boolean_field(
      review.detail_panel_copy_captured,
      "Copy review",
      :detail_panel_copy_captured
    )
    |> maybe_missing(
      review.detail_panel_copy_captured == true,
      "Copy review must capture selected detail panel limitation, next-action, and blocked-claim copy."
    )
    |> maybe_missing(
      unsupported_claims == [],
      "Copy review has unsupported blocked claim callouts: #{inspect(unsupported_claims)}."
    )
    |> maybe_missing(
      duplicate_claims == [],
      "Copy review has duplicate blocked claim callouts: #{inspect(duplicate_claims)}."
    )
    |> maybe_missing(
      missing_claims == [],
      "Copy review missing blocked claim callouts: #{inspect(missing_claims)}."
    )
  end

  defp missing_visual_density_review(missing, review, target_device_ids) do
    missing_target_device_ids = missing_review_target_device_ids(target_device_ids, review)
    undeclared_target_device_ids = undeclared_review_target_device_ids(target_device_ids, review)
    duplicate_target_device_ids = duplicate_review_target_device_ids(review)
    non_trimmed_target_device_ids = non_trimmed_review_target_device_ids(review)
    malformed_target_device_ids = malformed_review_target_device_ids(review)
    target_device_ids_container_valid? = review_target_device_ids_container_valid?(review)

    missing
    |> missing_review_field(review, "Visual density review", :artifact_path)
    |> missing_review_field(review, "Visual density review", :densest_fixture_artifact_path)
    |> malformed_string_field(review.artifact_path, "Visual density review", :artifact_path)
    |> malformed_string_field(
      review.densest_fixture_artifact_path,
      "Visual density review",
      :densest_fixture_artifact_path
    )
    |> non_trimmed_path(review.artifact_path, "Visual density review", :artifact_path)
    |> non_trimmed_path(
      review.densest_fixture_artifact_path,
      "Visual density review",
      :densest_fixture_artifact_path
    )
    |> non_relative_path(review.artifact_path, "Visual density review", :artifact_path)
    |> non_relative_path(
      review.densest_fixture_artifact_path,
      "Visual density review",
      :densest_fixture_artifact_path
    )
    |> missing_review_field(review, "Visual density review", :evidence_kind)
    |> malformed_enum_field(review.evidence_kind, "Visual density review", :evidence_kind)
    |> non_trimmed_enum(review.evidence_kind, "Visual density review", :evidence_kind)
    |> invalid_evidence_kind(review, nil, "Visual density review")
    |> missing_review_field(review, "Visual density review", :densest_fixture_evidence_kind)
    |> malformed_enum_field(
      review.densest_fixture_evidence_kind,
      "Visual density review",
      :densest_fixture_evidence_kind
    )
    |> non_trimmed_enum(
      review.densest_fixture_evidence_kind,
      "Visual density review",
      :densest_fixture_evidence_kind
    )
    |> maybe_missing(
      review.densest_fixture_evidence_kind == :screenshot,
      "Visual density review densest_fixture_evidence_kind must be screenshot."
    )
    |> missing_list_review_field(
      review,
      "Visual density review",
      :target_device_ids_reviewed
    )
    |> maybe_missing(
      target_device_ids_container_valid?,
      "Visual density review target_device_ids_reviewed must be a list."
    )
    |> maybe_missing(
      malformed_target_device_ids == [],
      "Visual density review target_device_ids_reviewed must contain only non-empty strings: #{inspect(malformed_target_device_ids)}."
    )
    |> maybe_missing(
      non_trimmed_target_device_ids == [],
      "Visual density review target_device_ids_reviewed must not contain ids with leading or trailing whitespace: #{inspect(non_trimmed_target_device_ids)}."
    )
    |> maybe_missing(
      duplicate_target_device_ids == [],
      "Visual density review has duplicate reviewed target devices: #{inspect(duplicate_target_device_ids)}."
    )
    |> maybe_missing(
      missing_target_device_ids == [],
      "Visual density review missing target devices: #{inspect(missing_target_device_ids)}."
    )
    |> maybe_missing(
      undeclared_target_device_ids == [],
      "Visual density review references undeclared target devices: #{inspect(undeclared_target_device_ids)}."
    )
    |> missing_boolean_review_field(
      review,
      "Visual density review",
      :row_truncation_reviewed
    )
    |> malformed_boolean_field(
      review.row_truncation_reviewed,
      "Visual density review",
      :row_truncation_reviewed
    )
    |> maybe_missing(
      review.row_truncation_reviewed == true,
      "Visual density review missing row truncation review."
    )
    |> missing_boolean_review_field(review, "Visual density review", :wrapping_reviewed)
    |> malformed_boolean_field(
      review.wrapping_reviewed,
      "Visual density review",
      :wrapping_reviewed
    )
    |> maybe_missing(
      review.wrapping_reviewed == true,
      "Visual density review missing wrapping review."
    )
    |> missing_boolean_review_field(review, "Visual density review", :tap_targets_reviewed)
    |> malformed_boolean_field(
      review.tap_targets_reviewed,
      "Visual density review",
      :tap_targets_reviewed
    )
    |> maybe_missing(
      review.tap_targets_reviewed == true,
      "Visual density review missing tap target review."
    )
    |> missing_boolean_review_field(
      review,
      "Visual density review",
      :detail_readability_reviewed
    )
    |> malformed_boolean_field(
      review.detail_readability_reviewed,
      "Visual density review",
      :detail_readability_reviewed
    )
    |> maybe_missing(
      review.detail_readability_reviewed == true,
      "Visual density review missing detail readability review."
    )
    |> missing_boolean_review_field(
      review,
      "Visual density review",
      :densest_fixture_captured
    )
    |> malformed_boolean_field(
      review.densest_fixture_captured,
      "Visual density review",
      :densest_fixture_captured
    )
    |> maybe_missing(
      review.densest_fixture_captured == true,
      "Visual density review missing densest fixture capture."
    )
  end

  defp duplicate_review_artifact_paths(missing, copy_review, visual_density_review) do
    duplicate_paths =
      [
        copy_review.review_path,
        visual_density_review.artifact_path,
        visual_density_review.densest_fixture_artifact_path
      ]
      |> Enum.filter(&present?/1)
      |> Enum.frequencies()
      |> Enum.filter(fn {_path, count} -> count > 1 end)
      |> Enum.map(fn {path, _count} -> path end)
      |> Enum.sort()

    if duplicate_paths == [] do
      missing
    else
      [
        "Copy review and visual density review must use separate artifact paths: #{inspect(duplicate_paths)}."
        | missing
      ]
    end
  end

  defp duplicate_review_evidence_artifact_paths(
         missing,
         copy_review,
         visual_density_review,
         state_evidence,
         interaction_evidence,
         selected_detail_evidence
       ) do
    evidence_paths =
      state_evidence
      |> artifact_path_set()
      |> MapSet.union(artifact_path_set(interaction_evidence))
      |> MapSet.union(artifact_path_set(selected_detail_evidence))

    review_paths =
      [
        copy_review.review_path,
        visual_density_review.artifact_path,
        visual_density_review.densest_fixture_artifact_path
      ]
      |> Enum.filter(&present?/1)
      |> MapSet.new()

    duplicate_paths =
      evidence_paths
      |> MapSet.intersection(review_paths)
      |> MapSet.to_list()
      |> Enum.sort()

    if duplicate_paths == [] do
      missing
    else
      [
        "Review artifacts reuse state or interaction evidence paths: #{inspect(duplicate_paths)}."
        | missing
      ]
    end
  end

  defp missing_review_target_device_ids(target_device_ids, review) do
    target_device_ids
    |> MapSet.difference(MapSet.new(review.target_device_ids_reviewed))
    |> MapSet.to_list()
    |> Enum.sort()
  end

  defp undeclared_review_target_device_ids(target_device_ids, review) do
    review.target_device_ids_reviewed
    |> MapSet.new()
    |> MapSet.difference(target_device_ids)
    |> MapSet.to_list()
    |> Enum.sort()
  end

  defp duplicate_review_target_device_ids(review) do
    review.target_device_ids_reviewed
    |> Enum.frequencies()
    |> Enum.filter(fn {_target_device_id, count} -> count > 1 end)
    |> Enum.map(fn {target_device_id, _count} -> target_device_id end)
    |> Enum.sort()
  end

  defp non_trimmed_review_target_device_ids(review) do
    review.target_device_ids_reviewed
    |> Enum.reject(&trim_stable_identity?/1)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp malformed_review_target_device_ids(review) do
    review.target_device_ids_reviewed
    |> Enum.reject(&(is_binary(&1) and present?(&1)))
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp review_target_device_ids_container_valid?(review),
    do: Map.get(review, :target_device_ids_reviewed_container_valid?, true)

  defp review_blocked_claims_container_valid?(review),
    do: Map.get(review, :blocked_claims_called_out_container_valid?, true)

  defp unsupported_blocked_claims(review) do
    review.blocked_claims_called_out
    |> Enum.reject(&(&1 in @required_blocked_claims))
    |> Enum.sort()
  end

  defp malformed_blocked_claims(review) do
    review.blocked_claims_called_out
    |> Enum.reject(&(is_atom(&1) or (is_binary(&1) and present?(&1))))
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp non_trimmed_blocked_claims(review) do
    review.blocked_claims_called_out
    |> Enum.reject(&trim_stable_enum?/1)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp duplicate_blocked_claims(review) do
    review.blocked_claims_called_out
    |> Enum.frequencies()
    |> Enum.filter(fn {_claim, count} -> count > 1 end)
    |> Enum.map(fn {claim, _count} -> claim end)
    |> Enum.sort()
  end

  defp missing_field(missing, struct, index, label, field) do
    if present?(Map.fetch!(struct, field)) do
      missing
    else
      ["#{label} #{index} missing #{field}." | missing]
    end
  end

  defp malformed_string_field(missing, value, label, field) do
    cond do
      is_nil(value) or is_binary(value) ->
        missing

      true ->
        ["#{label} #{field} must be a string." | missing]
    end
  end

  defp malformed_enum_field(missing, value, label, field) do
    cond do
      is_nil(value) or is_atom(value) or is_binary(value) ->
        missing

      true ->
        ["#{label} #{field} must be a string or atom." | missing]
    end
  end

  defp malformed_boolean_field(missing, value, label, field) do
    if is_boolean(value) do
      missing
    else
      ["#{label} #{field} must be a boolean." | missing]
    end
  end

  defp non_relative_paths(missing, values, label, field) do
    values
    |> Enum.with_index(1)
    |> Enum.reduce(missing, fn {value, index}, acc ->
      non_relative_path(
        acc,
        Map.fetch!(value, field),
        "#{label} #{index}",
        field
      )
    end)
  end

  defp non_trimmed_paths(missing, values, label, field) do
    values
    |> Enum.with_index(1)
    |> Enum.reduce(missing, fn {value, index}, acc ->
      non_trimmed_path(
        acc,
        Map.fetch!(value, field),
        "#{label} #{index}",
        field
      )
    end)
  end

  defp non_trimmed_path(missing, value, label, field) do
    if trim_stable_path?(value) do
      missing
    else
      ["#{label} #{field} must not have leading or trailing whitespace." | missing]
    end
  end

  defp non_trimmed_identity(missing, value, label, field) do
    if trim_stable_identity?(value) do
      missing
    else
      ["#{label} #{field} must not have leading or trailing whitespace." | missing]
    end
  end

  defp non_trimmed_text(missing, value, label, field) do
    if trim_stable_text?(value) do
      missing
    else
      ["#{label} #{field} must not have leading or trailing whitespace." | missing]
    end
  end

  defp non_trimmed_enum(missing, value, label, field) do
    if trim_stable_enum?(value) do
      missing
    else
      ["#{label} #{field} must not have leading or trailing whitespace." | missing]
    end
  end

  defp non_relative_path(missing, value, label, field) do
    if relative_artifact_path?(value) do
      missing
    else
      ["#{label} #{field} must be a relative artifact path." | missing]
    end
  end

  defp invalid_evidence_kind(missing, item, index, label) do
    if item.evidence_kind in @allowed_evidence_kinds do
      missing
    else
      [
        "#{indexed_label(label, index)} has unsupported evidence_kind #{inspect(item.evidence_kind)}; expected #{inspect(@allowed_evidence_kinds)}."
        | missing
      ]
    end
  end

  defp indexed_label(label, nil), do: label
  defp indexed_label(label, index), do: "#{label} #{index}"

  defp missing_review_field(missing, struct, label, field) do
    if present?(Map.fetch!(struct, field)) do
      missing
    else
      ["#{label} missing #{field}." | missing]
    end
  end

  defp missing_boolean_review_field(missing, struct, label, field) do
    if Map.get(struct, :"#{field}_present?", true) do
      missing
    else
      ["#{label} missing #{field}." | missing]
    end
  end

  defp missing_list_review_field(missing, struct, label, field) do
    if Map.get(struct, :"#{field}_present?", true) do
      missing
    else
      ["#{label} missing #{field}." | missing]
    end
  end

  defp missing_allowed_wording(missing, review) do
    if review.allowed_wording == @allowed_wording do
      missing
    else
      ["Copy review must use the approved nearby/observed wording." | missing]
    end
  end

  defp maybe_missing(missing, true, _message), do: missing
  defp maybe_missing(missing, false, message), do: [message | missing]

  defp target_device(%TargetDevice{} = device), do: device

  defp target_device(input) when is_map(input) do
    struct!(TargetDevice, %{
      device_id: get_field(input, :device_id),
      device_model: get_field(input, :device_model),
      os_or_api_version: get_field(input, :os_or_api_version),
      screen_size_class: get_field(input, :screen_size_class),
      app_build_id: get_field(input, :app_build_id),
      evidence_path: get_field(input, :evidence_path)
    })
  end

  defp target_device(_input), do: target_device(%{})

  defp state_evidence(%StateEvidence{} = evidence), do: evidence

  defp state_evidence(input) when is_map(input) do
    struct!(StateEvidence, %{
      state: atom_value(get_field(input, :state)),
      target_device_id: get_field(input, :target_device_id),
      evidence_kind: atom_value(get_field(input, :evidence_kind)),
      artifact_path: get_field(input, :artifact_path),
      notes: get_field(input, :notes)
    })
  end

  defp state_evidence(_input), do: state_evidence(%{})

  defp interaction_evidence(%InteractionEvidence{} = evidence), do: evidence

  defp interaction_evidence(input) when is_map(input) do
    struct!(InteractionEvidence, %{
      interaction: atom_value(get_field(input, :interaction)),
      target_device_id: get_field(input, :target_device_id),
      evidence_kind: atom_value(get_field(input, :evidence_kind)),
      artifact_path: get_field(input, :artifact_path),
      notes: get_field(input, :notes)
    })
  end

  defp interaction_evidence(_input), do: interaction_evidence(%{})

  defp selected_detail_evidence(%SelectedDetailEvidence{} = evidence), do: evidence

  defp selected_detail_evidence(input) when is_map(input) do
    struct!(SelectedDetailEvidence, %{
      state: atom_value(get_field(input, :state)),
      target_device_id: get_field(input, :target_device_id),
      evidence_kind: atom_value(get_field(input, :evidence_kind)),
      artifact_path: get_field(input, :artifact_path),
      limitation_copy: get_field(input, :limitation_copy),
      next_action_copy: get_field(input, :next_action_copy),
      blocked_claim_copy: get_field(input, :blocked_claim_copy),
      notes: get_field(input, :notes)
    })
  end

  defp selected_detail_evidence(_input), do: selected_detail_evidence(%{})

  defp copy_review(%CopyReview{} = review), do: review

  defp copy_review(input) when is_map(input) do
    target_device_ids_reviewed = get_field(input, :target_device_ids_reviewed, [])
    blocked_claims_called_out = get_field(input, :blocked_claims_called_out, [])

    struct!(CopyReview, %{
      review_path: get_field(input, :review_path),
      evidence_kind: atom_value(get_field(input, :evidence_kind)),
      target_device_ids_reviewed: target_device_id_list(target_device_ids_reviewed),
      target_device_ids_reviewed_container_valid?: is_list(target_device_ids_reviewed),
      target_device_ids_reviewed_present?: has_field?(input, :target_device_ids_reviewed),
      allowed_wording: get_field(input, :allowed_wording),
      blocked_claims_called_out: atom_list(blocked_claims_called_out),
      blocked_claims_called_out_container_valid?: is_list(blocked_claims_called_out),
      blocked_claims_called_out_present?: has_field?(input, :blocked_claims_called_out),
      warning_text_captured: get_field(input, :warning_text_captured, false),
      warning_text_captured_present?: has_field?(input, :warning_text_captured),
      control_summaries_captured: get_field(input, :control_summaries_captured, false),
      control_summaries_captured_present?: has_field?(input, :control_summaries_captured),
      state_blocked_claim_copy_captured:
        get_field(input, :state_blocked_claim_copy_captured, false),
      state_blocked_claim_copy_captured_present?:
        has_field?(input, :state_blocked_claim_copy_captured),
      detail_panel_copy_captured: get_field(input, :detail_panel_copy_captured, false),
      detail_panel_copy_captured_present?: has_field?(input, :detail_panel_copy_captured)
    })
  end

  defp copy_review(_input), do: copy_review(%{})

  defp visual_density_review(%VisualDensityReview{} = review), do: review

  defp visual_density_review(input) when is_map(input) do
    target_device_ids_reviewed = get_field(input, :target_device_ids_reviewed, [])

    struct!(VisualDensityReview, %{
      artifact_path: get_field(input, :artifact_path),
      evidence_kind: atom_value(get_field(input, :evidence_kind)),
      densest_fixture_artifact_path: get_field(input, :densest_fixture_artifact_path),
      densest_fixture_evidence_kind: atom_value(get_field(input, :densest_fixture_evidence_kind)),
      target_device_ids_reviewed: target_device_id_list(target_device_ids_reviewed),
      target_device_ids_reviewed_container_valid?: is_list(target_device_ids_reviewed),
      target_device_ids_reviewed_present?: has_field?(input, :target_device_ids_reviewed),
      row_truncation_reviewed: get_field(input, :row_truncation_reviewed, false),
      wrapping_reviewed: get_field(input, :wrapping_reviewed, false),
      tap_targets_reviewed: get_field(input, :tap_targets_reviewed, false),
      detail_readability_reviewed: get_field(input, :detail_readability_reviewed, false),
      densest_fixture_captured: get_field(input, :densest_fixture_captured, false),
      row_truncation_reviewed_present?: has_field?(input, :row_truncation_reviewed),
      wrapping_reviewed_present?: has_field?(input, :wrapping_reviewed),
      tap_targets_reviewed_present?: has_field?(input, :tap_targets_reviewed),
      detail_readability_reviewed_present?: has_field?(input, :detail_readability_reviewed),
      densest_fixture_captured_present?: has_field?(input, :densest_fixture_captured)
    })
  end

  defp visual_density_review(_input), do: visual_density_review(%{})

  defp get_field(input, field, default \\ nil) when is_atom(field) do
    Map.get(input, field, Map.get(input, Atom.to_string(field), default))
  end

  defp has_field?(input, field) when is_atom(field) do
    Map.has_key?(input, field) or Map.has_key?(input, Atom.to_string(field))
  end

  defp atom_list(values) when is_list(values), do: Enum.map(values, &list_atom_value/1)
  defp atom_list(_value), do: []

  defp list_atom_value(value) when is_binary(value) do
    if present?(value), do: atom_value(value), else: value
  end

  defp list_atom_value(value), do: atom_value(value)

  defp list_value(value) when is_list(value), do: value
  defp list_value(_value), do: []

  defp target_device_id_list(values) when is_list(values), do: values
  defp target_device_id_list(_value), do: []

  defp relative_artifact_path?(value) when is_binary(value) do
    trimmed = String.trim(value)

    present?(trimmed) and
      not String.match?(trimmed, ~r/^[A-Za-z]:[\\\/]/) and
      not String.starts_with?(trimmed, ["/", "\\\\", "~", "file:", "http:", "https:"]) and
      not String.contains?(trimmed, "..")
  end

  defp relative_artifact_path?(_value), do: true

  defp trim_stable_path?(value) when is_binary(value),
    do: not present?(value) or value == String.trim(value)

  defp trim_stable_path?(_value), do: true

  defp trim_stable_identity?(value) when is_binary(value),
    do: not present?(value) or value == String.trim(value)

  defp trim_stable_identity?(_value), do: true

  defp trim_stable_text?(value) when is_binary(value),
    do: not present?(value) or value == String.trim(value)

  defp trim_stable_text?(_value), do: true

  defp trim_stable_enum?(value) when is_binary(value),
    do: not present?(value) or value == String.trim(value)

  defp trim_stable_enum?(_value), do: true

  defp atom_value(value) when is_atom(value), do: value

  defp atom_value(value) when is_binary(value) do
    String.to_existing_atom(value)
  rescue
    ArgumentError -> value
  end

  defp atom_value(value), do: value

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(value), do: not is_nil(value)
end
