defmodule Mob.Node.BLE.LocalFullMessageResolutionEvidenceReview do
  @moduledoc """
  Pure review contract for full-message-resolution transport evidence metadata.

  This module validates operator-supplied metadata for the
  `LocalFetchTransportValidationPlan` gates. It does not open BLE connections,
  perform GATT fetch, scan, advertise, route, persist, ACK, retry, encrypt,
  authenticate, fragment, or claim full message resolution.
  """

  alias Mob.Node.BLE.LocalFetchTransportValidationPlan

  defmodule Evidence do
    @moduledoc false

    @derive {JSON.Encoder,
             only: [:artifact_path, :summary, :test_command, :blocked_claims_called_out]}
    @enforce_keys [
      :artifact_path,
      :summary,
      :test_command,
      :blocked_claims_called_out,
      :blocked_claims_called_out_container_valid?
    ]
    defstruct @enforce_keys
  end

  @required_gates [
    :current_gatt_blocker_recorded,
    :candidate_transport_decision,
    :standalone_interop_matrix,
    :constrained_fetch_exchange,
    :canonical_replay_resolution,
    :negative_failure_matrix,
    :release_artifact_linkage
  ]

  @required_blocked_claims [
    :full_message_resolution,
    :known_good_transport,
    :transport_validated,
    :gatt_fetch_success,
    :resolved_message,
    :message_delivery,
    :trusted_message,
    :trusted_delivery,
    :routed_delivery,
    :background_delivery,
    :guaranteed_delivery,
    :fake_success,
    :whole_project_complete
  ]

  @required_gate_blocked_claims %{
    current_gatt_blocker_recorded: [:known_bad_pair_as_success],
    candidate_transport_decision: [:unvalidated_transport_selection],
    standalone_interop_matrix: [:interop_without_fetch_resolution],
    constrained_fetch_exchange: [:missing_fetch_exchange],
    canonical_replay_resolution: [:hash_mismatch_resolution],
    negative_failure_matrix: [:unresolved_ref_promoted_to_success],
    release_artifact_linkage: [:release_overclaim]
  }

  @spec required_gates() :: [atom()]
  def required_gates, do: @required_gates

  @spec required_blocked_claims() :: [atom()]
  def required_blocked_claims, do: @required_blocked_claims

  @spec required_gate_blocked_claims() :: %{atom() => [atom()]}
  def required_gate_blocked_claims do
    plan_claims =
      LocalFetchTransportValidationPlan.snapshot()
      |> gate_blocked_claims()
      |> Map.take(@required_gates)

    Map.merge(@required_gate_blocked_claims, plan_claims, fn _gate_id,
                                                             review_claims,
                                                             plan_claims ->
      Enum.uniq(review_claims ++ plan_claims)
    end)
  end

  @spec review(map()) :: map()
  def review(input) when is_map(input) do
    transport_validation_plan = LocalFetchTransportValidationPlan.snapshot()
    gate_blocked_claims = required_gate_blocked_claims()

    evidence_by_gate =
      @required_gates
      |> Map.new(fn gate_id ->
        {gate_id, evidence(get_field(input, gate_id, %{}))}
      end)

    missing =
      []
      |> missing_gate_sections(input)
      |> malformed_gate_sections(input)
      |> missing_gate_evidence(evidence_by_gate, gate_blocked_claims)
      |> Enum.reverse()

    %{
      review_version: 1,
      boundary: :full_message_resolution_transport_evidence_review,
      status: if(missing == [], do: :ready, else: :open),
      full_resolution_transport_evidence_complete?: missing == [],
      real_fetch_transport_validated?: false,
      full_message_resolution_claim_allowed?: false,
      known_good_transport_claim_allowed?: false,
      gatt_fetch_success_claim_allowed?: false,
      message_delivery_claim_allowed?: false,
      trusted_message_claim_allowed?: false,
      transport_validation_plan: transport_validation_plan,
      required_gates: @required_gates,
      required_blocked_claims: @required_blocked_claims,
      evidence_by_gate: evidence_by_gate,
      missing: missing,
      notes: [
        "Ready evidence means the supplied metadata covers the full-resolution transport validation gates.",
        "This review does not enable real fetch transport, full-message resolution, delivery, trust, routing, or background claims.",
        "Beacon refs remain pointers until hardware evidence retrieves and replay-parses a matching MessageEnvelope."
      ]
    }
  end

  @spec json_review(map()) :: map()
  def json_review(input) do
    input
    |> review()
    |> JSON.encode!()
    |> JSON.decode!()
  end

  @spec template_input() :: map()
  def template_input do
    @required_gates
    |> Map.new(fn gate_id ->
      {Atom.to_string(gate_id),
       %{
         "artifact_path" => "",
         "summary" => "",
         "test_command" => "",
         "blocked_claims_called_out" => []
       }}
    end)
  end

  defp missing_gate_sections(missing, input) do
    Enum.reduce(@required_gates, missing, fn gate_id, acc ->
      if has_field?(input, gate_id) do
        acc
      else
        ["#{gate_id} evidence section missing." | acc]
      end
    end)
  end

  defp malformed_gate_sections(missing, input) do
    Enum.reduce(@required_gates, missing, fn gate_id, acc ->
      value = get_field(input, gate_id, %{})

      if is_map(value) do
        acc
      else
        ["#{gate_id} evidence section must be an object." | acc]
      end
    end)
  end

  defp missing_gate_evidence(missing, evidence_by_gate, gate_blocked_claims) do
    Enum.reduce(@required_gates, missing, fn gate_id, acc ->
      item = Map.fetch!(evidence_by_gate, gate_id)
      missing_claims = @required_blocked_claims -- item.blocked_claims_called_out

      missing_gate_claims =
        Map.get(gate_blocked_claims, gate_id, []) -- item.blocked_claims_called_out

      []
      |> missing_field(item, gate_id, :artifact_path)
      |> malformed_string_field(item, gate_id, :artifact_path)
      |> non_trimmed_text(item, gate_id, :artifact_path)
      |> non_relative_artifact_path(item, gate_id)
      |> missing_field(item, gate_id, :summary)
      |> malformed_string_field(item, gate_id, :summary)
      |> non_trimmed_text(item, gate_id, :summary)
      |> missing_field(item, gate_id, :test_command)
      |> malformed_string_field(item, gate_id, :test_command)
      |> non_trimmed_text(item, gate_id, :test_command)
      |> maybe_missing(
        item.blocked_claims_called_out_container_valid?,
        "#{gate_id} blocked_claims_called_out must be a list."
      )
      |> maybe_missing(
        missing_claims == [],
        "#{gate_id} missing blocked claim callouts: #{inspect(missing_claims)}."
      )
      |> maybe_missing(
        missing_gate_claims == [],
        "#{gate_id} missing gate-specific blocked claim callouts: #{inspect(missing_gate_claims)}."
      )
      |> Kernel.++(acc)
    end)
  end

  defp gate_blocked_claims(plan) do
    Map.new(plan.gates, &{&1.id, &1.blocked_claims})
  end

  defp missing_field(missing, evidence, gate_id, field) do
    if present?(Map.fetch!(evidence, field)) do
      missing
    else
      ["#{gate_id} missing #{field}." | missing]
    end
  end

  defp malformed_string_field(missing, evidence, gate_id, field) do
    value = Map.fetch!(evidence, field)

    if is_nil(value) or is_binary(value) do
      missing
    else
      ["#{gate_id} #{field} must be a string." | missing]
    end
  end

  defp non_trimmed_text(missing, evidence, gate_id, field) do
    value = Map.fetch!(evidence, field)

    if not is_binary(value) or value == String.trim(value) do
      missing
    else
      ["#{gate_id} #{field} must not have leading or trailing whitespace." | missing]
    end
  end

  defp non_relative_artifact_path(missing, evidence, gate_id) do
    if relative_artifact_path?(evidence.artifact_path) do
      missing
    else
      ["#{gate_id} artifact_path must be a relative artifact path." | missing]
    end
  end

  defp maybe_missing(missing, true, _message), do: missing
  defp maybe_missing(missing, false, message), do: [message | missing]

  defp evidence(%Evidence{} = evidence), do: evidence

  defp evidence(input) when is_map(input) do
    struct!(Evidence, %{
      artifact_path: get_field(input, :artifact_path),
      summary: get_field(input, :summary),
      test_command: get_field(input, :test_command),
      blocked_claims_called_out: atom_list(get_field(input, :blocked_claims_called_out, [])),
      blocked_claims_called_out_container_valid?:
        is_list(get_field(input, :blocked_claims_called_out, []))
    })
  end

  defp evidence(_input), do: evidence(%{})

  defp has_field?(input, field) when is_atom(field) do
    Map.has_key?(input, field) or Map.has_key?(input, Atom.to_string(field))
  end

  defp get_field(input, field, default \\ nil) when is_atom(field) do
    Map.get(input, field, Map.get(input, Atom.to_string(field), default))
  end

  defp atom_list(values) when is_list(values), do: Enum.map(values, &atom_value/1)
  defp atom_list(_value), do: []

  defp atom_value(value) when is_atom(value), do: value

  defp atom_value(value) when is_binary(value) do
    String.to_existing_atom(value)
  rescue
    ArgumentError -> value
  end

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(value), do: not is_nil(value)

  defp relative_artifact_path?(value) when is_binary(value) do
    trimmed = String.trim(value)

    present?(trimmed) and
      not String.match?(trimmed, ~r/^[A-Za-z]:[\\\/]/) and
      not String.starts_with?(trimmed, ["/", "\\\\", "~", "file:", "http:", "https:"]) and
      not String.contains?(trimmed, "..")
  end

  defp relative_artifact_path?(_value), do: true
end
