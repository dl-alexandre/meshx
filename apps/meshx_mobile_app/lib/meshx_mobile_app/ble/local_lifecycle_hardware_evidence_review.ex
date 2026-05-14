defmodule MeshxMobileApp.BLE.LocalLifecycleHardwareEvidenceReview do
  @moduledoc """
  Pure review contract for mobile BLE lifecycle hardware evidence metadata.

  This module validates operator-supplied metadata for the
  `LocalLifecycleHardwareValidationPlan` gates. It does not start Android
  services, request iOS background modes, schedule retries, scan, advertise,
  gossip, route, persist, ACK, retry, fetch, encrypt, authenticate, or run
  background work.
  """

  alias MeshxMobileApp.BLE.LocalLifecycleHardwareValidationPlan

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
    :target_device_matrix,
    :android_foreground_service_backgrounding,
    :android_background_ble_policy,
    :ios_background_ble_policy,
    :restart_and_cancellation,
    :scheduled_retry_bounds,
    :background_gossip_limits,
    :negative_claim_review
  ]

  @required_blocked_claims [
    :android_foreground_service_ble,
    :android_background_scan,
    :android_background_advertise,
    :ios_background_scan,
    :ios_background_advertise,
    :automatic_ble_restart,
    :scheduled_retry,
    :background_gossip,
    :background_delivery
  ]

  @required_evidence_types %{
    target_device_matrix: :target_device_matrix,
    android_foreground_service_backgrounding: :android_foreground_service_log,
    android_background_ble_policy: :android_background_policy_fixture,
    ios_background_ble_policy: :ios_background_policy_fixture,
    restart_and_cancellation: :restart_cancellation_fixture,
    scheduled_retry_bounds: :scheduled_retry_fixture,
    background_gossip_limits: :background_gossip_limits_fixture,
    negative_claim_review: :lifecycle_negative_fixture_matrix
  }

  @spec required_gates() :: [atom()]
  def required_gates, do: @required_gates

  @spec required_blocked_claims() :: [atom()]
  def required_blocked_claims, do: @required_blocked_claims

  @spec required_evidence_types() :: %{atom() => atom()}
  def required_evidence_types, do: @required_evidence_types

  @spec required_gate_blocked_claims() :: %{atom() => [atom()]}
  def required_gate_blocked_claims do
    LocalLifecycleHardwareValidationPlan.snapshot()
    |> gate_blocked_claims()
    |> Map.take(@required_gates)
  end

  @spec review(map()) :: map()
  def review(input) when is_map(input) do
    hardware_validation_plan = LocalLifecycleHardwareValidationPlan.snapshot()

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
      boundary: :mobile_ble_lifecycle_hardware_evidence_review,
      status: if(missing == [], do: :ready, else: :open),
      lifecycle_hardware_evidence_complete?: missing == [],
      android_foreground_service_claim_allowed?: false,
      android_background_ble_claim_allowed?: false,
      ios_background_claim_allowed?: false,
      background_ble_claim_allowed?: false,
      restart_claim_allowed?: false,
      scheduled_retry_claim_allowed?: false,
      background_gossip_claim_allowed?: false,
      delivery_claim_allowed?: false,
      hardware_validation_plan: hardware_validation_plan,
      required_gates: @required_gates,
      required_blocked_claims: @required_blocked_claims,
      evidence_by_gate: evidence_by_gate,
      missing: missing,
      notes: [
        "Ready evidence means the supplied metadata covers the lifecycle hardware validation gates.",
        "This review does not enable foreground-service, background BLE, restart, retry, gossip, or delivery claims.",
        "Foreground/manual BLE remains the only validated lifecycle mode until implementation-backed device evidence passes."
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
    struct!(Evidence, %{
      artifact_path: get_field(input, :artifact_path),
      summary: get_field(input, :summary),
      test_command: get_field(input, :test_command),
      evidence_type: atom_value(get_field(input, :evidence_type)),
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
