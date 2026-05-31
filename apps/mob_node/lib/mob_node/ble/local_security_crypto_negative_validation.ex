defmodule Mob.Node.BLE.LocalSecurityCryptoNegativeValidation do
  @moduledoc """
  Executable negative validation for authenticated local BLE message claims.

  This module runs caller-supplied crypto/replay scenarios through
  `LocalSecurityCanonicalReplayDecision` and normalizes the outcome into an
  auditable pass/fail result. It does not create keys, persist trust, persist
  replay state, fetch, route, ACK, retry, encrypt, or run background work.
  """

  alias Mob.Node.BLE.LocalSecurityCanonicalReplayDecision
  alias Mob.Node.BLE.LocalSecurityReplayProtection.State

  @required_case_ids [
    :tampered_transport_payload,
    :signature_mismatch,
    :binding_key_mismatch,
    :duplicate_replay,
    :trusted_policy_without_matching_binding,
    :blocked_peer_policy,
    :revoked_peer_policy,
    :hash_only_beacon_ref,
    :passive_peer_label,
    :stale_beacon_ref
  ]

  @blocked_claims [:trusted_message, :trusted_delivery, :routed_delivery, :guaranteed_delivery]

  @type case_result :: %{
          required(:id) => atom(),
          required(:passed?) => boolean(),
          required(:expected_status) => atom(),
          required(:actual_status) => atom() | nil,
          required(:expected_reason) => atom() | nil,
          required(:actual_reasons) => [atom()],
          required(:trusted_message?) => boolean(),
          required(:trusted_delivery_claim_allowed?) => boolean(),
          required(:blocked_claims) => [atom()],
          required(:notes) => [binary()]
        }

  @spec required_case_ids() :: [atom()]
  def required_case_ids, do: @required_case_ids

  @spec evaluate_cases([map()]) :: map()
  def evaluate_cases(cases) when is_list(cases) do
    results = Enum.map(cases, &evaluate_case/1)
    observed_ids = Enum.map(results, & &1.id)
    missing_case_ids = @required_case_ids -- observed_ids

    %{
      validation_version: 1,
      boundary: :crypto_backed_local_security_negative_validation,
      required_case_ids: @required_case_ids,
      missing_case_ids: missing_case_ids,
      case_count: length(results),
      passed_count: Enum.count(results, & &1.passed?),
      failed_count: Enum.count(results, &(not &1.passed?)),
      all_required_cases_present?: missing_case_ids == [],
      trusted_claims_allowed?: false,
      delivery_claims_allowed?: false,
      blocked_claims: @blocked_claims,
      cases: results,
      notes: [
        "These are executable negative validations over supplied crypto/replay fixtures.",
        "Passing cases block over-promotion; they do not create a persistent trust store or delivery proof."
      ]
    }
  end

  def evaluate_cases(_cases), do: evaluate_cases([])

  @spec evaluate_case(map()) :: case_result()
  def evaluate_case(
        %{id: id, initial_replay_state: %State{} = state, attempts: attempts} = scenario
      )
      when is_list(attempts) and attempts != [] do
    expected_status = Map.get(scenario, :expected_status, :rejected)
    expected_reason = Map.get(scenario, :expected_reason)

    {actual_status, reasons, trusted?, delivery?, blocked_claims} =
      attempts
      |> Enum.reduce({state, nil}, fn attempt, {replay_state, _last} ->
        result =
          LocalSecurityCanonicalReplayDecision.decide(
            Map.fetch!(attempt, :event),
            Map.fetch!(attempt, :proof),
            Map.fetch!(attempt, :binding),
            replay_state,
            Map.get(attempt, :opts, [])
          )

        {next_state(result, replay_state), result}
      end)
      |> elem(1)
      |> normalize_result()

    passed? =
      actual_status == expected_status and
        trusted? == false and
        delivery? == false and
        (is_nil(expected_reason) or expected_reason in reasons)

    %{
      id: id,
      passed?: passed?,
      expected_status: expected_status,
      actual_status: actual_status,
      expected_reason: expected_reason,
      actual_reasons: reasons,
      trusted_message?: trusted?,
      trusted_delivery_claim_allowed?: delivery?,
      blocked_claims: blocked_claims,
      notes: [
        "Negative case must not produce a trusted message.",
        "Negative case must not allow trusted delivery wording."
      ]
    }
  end

  def evaluate_case(%{id: id} = scenario) do
    expected_status = Map.get(scenario, :expected_status, :rejected)

    %{
      id: id,
      passed?: false,
      expected_status: expected_status,
      actual_status: nil,
      expected_reason: Map.get(scenario, :expected_reason),
      actual_reasons: [:invalid_negative_validation_case],
      trusted_message?: false,
      trusted_delivery_claim_allowed?: false,
      blocked_claims: @blocked_claims,
      notes: ["Scenario is malformed and was not executed."]
    }
  end

  def evaluate_case(_scenario), do: evaluate_case(%{id: :invalid_negative_validation_case})

  defp next_state({:ok, %State{} = state, _decision}, _fallback), do: state
  defp next_state({:error, _reason, %State{} = state, _decision}, _fallback), do: state
  defp next_state(_result, fallback), do: fallback

  defp normalize_result({:ok, %State{}, decision}) do
    normalize_decision(decision)
  end

  defp normalize_result({:error, reason, %State{}, decision}) do
    {status, reasons, trusted?, delivery?, blocked_claims} = normalize_decision(decision)
    {status || :rejected, Enum.uniq([reason | reasons]), trusted?, delivery?, blocked_claims}
  end

  defp normalize_result(_result),
    do: {:rejected, [:invalid_negative_validation_result], false, false, @blocked_claims}

  defp normalize_decision(decision) when is_map(decision) do
    {
      Map.get(decision, :status),
      Map.get(decision, :reasons, []),
      Map.get(decision, :trusted_message?, false),
      Map.get(decision, :trusted_delivery_claim_allowed?, false),
      Map.get(decision, :blocked_claims, @blocked_claims)
    }
  end

  defp normalize_decision(_decision), do: {:rejected, [], false, false, @blocked_claims}
end
