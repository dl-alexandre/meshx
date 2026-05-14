defmodule MeshxMobileApp.BLE.LocalRoutingProductionEvidenceReview do
  @moduledoc """
  Pure review contract for production routing evidence metadata.

  This module validates operator-supplied metadata for the
  `LocalRoutingHardwareValidationPlan` gates. It does not route, forward,
  scan, advertise, persist, ACK, retry, fetch, encrypt, authenticate, or run
  background work.
  """

  alias MeshxMobileApp.BLE.LocalRoutingHardwareValidationPlan

  defmodule Evidence do
    @moduledoc false

    @derive {JSON.Encoder,
             only: [
               :artifact_path,
               :summary,
               :test_command,
               :evidence_type,
               :blocked_claims_called_out
             ]}
    @enforce_keys [
      :artifact_path,
      :summary,
      :test_command,
      :evidence_type,
      :blocked_claims_called_out,
      :blocked_claims_called_out_container_valid?
    ]
    defstruct @enforce_keys
  end

  @required_gates [
    :route_table_state_model,
    :deterministic_route_selection,
    :forwarding_service_boundary,
    :delivery_semantics_policy,
    :multi_hop_hardware_rig,
    :ttl_loop_and_suppression_evidence,
    :release_artifact_evidence,
    :negative_claim_review
  ]

  @required_blocked_claims [
    :route_table_available,
    :route_selection_available,
    :live_forwarding_service,
    :routed_delivery,
    :guaranteed_delivery,
    :ack_backed_delivery,
    :retry_backed_delivery,
    :multi_hop_hardware_routing
  ]

  @required_evidence_types %{
    route_table_state_model: :route_table_state_model,
    deterministic_route_selection: :route_selection_policy,
    forwarding_service_boundary: :forwarding_service_boundary,
    delivery_semantics_policy: :delivery_semantics_policy,
    multi_hop_hardware_rig: :multi_hop_hardware_rig,
    ttl_loop_and_suppression_evidence: :ttl_loop_suppression_fixture,
    release_artifact_evidence: :release_artifact_review,
    negative_claim_review: :routing_negative_fixture_matrix
  }

  @spec required_gates() :: [atom()]
  def required_gates, do: @required_gates

  @spec required_blocked_claims() :: [atom()]
  def required_blocked_claims, do: @required_blocked_claims

  @spec required_evidence_types() :: %{atom() => atom()}
  def required_evidence_types, do: @required_evidence_types

  @spec required_gate_blocked_claims() :: %{atom() => [atom()]}
  def required_gate_blocked_claims do
    LocalRoutingHardwareValidationPlan.snapshot()
    |> gate_blocked_claims()
    |> Map.take(@required_gates)
  end

  @spec review(map()) :: map()
  def review(input) when is_map(input) do
    hardware_validation_plan = LocalRoutingHardwareValidationPlan.snapshot()

    gate_blocked_claims =
      hardware_validation_plan |> gate_blocked_claims() |> Map.take(@required_gates)

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
      boundary: :production_routing_evidence_review,
      status: if(missing == [], do: :ready, else: :open),
      production_routing_evidence_complete?: missing == [],
      route_table_claim_allowed?: false,
      route_selection_claim_allowed?: false,
      forwarding_claim_allowed?: false,
      routed_delivery_claim_allowed?: false,
      guaranteed_delivery_claim_allowed?: false,
      multi_hop_hardware_claim_allowed?: false,
      hardware_validation_plan: hardware_validation_plan,
      required_gates: @required_gates,
      required_blocked_claims: @required_blocked_claims,
      evidence_by_gate: evidence_by_gate,
      missing: missing,
      notes: [
        "Ready evidence means the supplied metadata covers the production routing validation gates.",
        "This review does not enable routing, forwarding, ACK/retry, delivery, or multi-hop hardware claims.",
        "Replay gossip and route candidates remain non-routing evidence until implementation-backed gates pass."
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
         "evidence_type" =>
           @required_evidence_types
           |> Map.fetch!(gate_id)
           |> Atom.to_string(),
         "blocked_claims_called_out" => []
       }}
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
      |> missing_field(item, gate_id, :evidence_type)
      |> wrong_evidence_type(item, gate_id)
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

  defp missing_gate_sections(missing, input) do
    Enum.reduce(@required_gates, missing, fn gate_id, acc ->
      if has_field?(input, gate_id) do
        acc
      else
        ["Missing #{gate_id} evidence section." | acc]
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

  defp wrong_evidence_type(missing, evidence, gate_id) do
    expected = Map.fetch!(@required_evidence_types, gate_id)

    if evidence.evidence_type == expected do
      missing
    else
      ["#{gate_id} evidence_type must be #{inspect(expected)}." | missing]
    end
  end

  defp maybe_missing(missing, true, _message), do: missing
  defp maybe_missing(missing, false, message), do: [message | missing]

  defp evidence(%Evidence{} = evidence), do: evidence

  defp evidence(input) when is_map(input) do
    blocked_claims_called_out = get_field(input, :blocked_claims_called_out, [])

    struct!(Evidence, %{
      artifact_path: get_field(input, :artifact_path),
      summary: get_field(input, :summary),
      test_command: get_field(input, :test_command),
      evidence_type: atom_value(get_field(input, :evidence_type)),
      blocked_claims_called_out: atom_list(blocked_claims_called_out),
      blocked_claims_called_out_container_valid?: is_list(blocked_claims_called_out)
    })
  end

  defp evidence(_input), do: evidence(%{})

  defp get_field(input, field, default \\ nil) when is_atom(field) do
    Map.get(input, field, Map.get(input, Atom.to_string(field), default))
  end

  defp has_field?(input, field) when is_atom(field) do
    Map.has_key?(input, field) or Map.has_key?(input, Atom.to_string(field))
  end

  defp atom_list(values) when is_list(values), do: Enum.map(values, &atom_value/1)
  defp atom_list(_value), do: []

  defp atom_value(value) when is_atom(value), do: value

  defp atom_value(value) when is_binary(value) do
    String.to_existing_atom(value)
  rescue
    ArgumentError -> value
  end

  defp atom_value(value), do: value

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
