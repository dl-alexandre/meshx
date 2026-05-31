defmodule Mob.Node.BLE.LocalSecurityTrustLifecycleValidation do
  @moduledoc """
  Executable trust lifecycle validation for supplied local security policy.

  This module validates key-rotation and revocation semantics over the pure
  operator trust policy boundary. It does not persist trust, discover keys,
  rotate keys in production, sync revocation, verify transport delivery, fetch,
  route, ACK, retry, encrypt, or run background work.
  """

  alias Mob.Node.BLE.{
    LocalSecurityOperatorTrustPolicy,
    LocalSecurityPeerEnrollment
  }

  @blocked_claims [
    :persistent_trust_store,
    :automatic_key_discovery,
    :key_rotation,
    :revocation_sync,
    :trusted_delivery
  ]

  @required_case_ids [
    :new_key_starts_unknown,
    :old_key_trust_does_not_transfer,
    :explicit_successor_key_can_be_trusted,
    :blocked_key_fails_closed,
    :revoked_key_fails_closed,
    :passive_observation_cannot_rotate_key
  ]

  @type case_result :: %{
          required(:id) => atom(),
          required(:passed?) => boolean(),
          required(:expected_state) => atom(),
          required(:actual_state) => atom() | nil,
          required(:trusted_peer_state?) => boolean(),
          required(:blocked_claims) => [atom()],
          required(:notes) => [binary()]
        }

  @spec required_case_ids() :: [atom()]
  def required_case_ids, do: @required_case_ids

  @spec snapshot() :: map()
  def snapshot do
    cases = run_cases()
    observed_ids = Enum.map(cases, & &1.id)
    missing_case_ids = @required_case_ids -- observed_ids

    %{
      validation_version: 1,
      boundary: :local_security_trust_lifecycle_validation,
      case_count: length(cases),
      passed_count: Enum.count(cases, & &1.passed?),
      failed_count: Enum.count(cases, &(not &1.passed?)),
      required_case_ids: @required_case_ids,
      missing_case_ids: missing_case_ids,
      all_required_cases_present?: missing_case_ids == [],
      all_cases_passed?: Enum.all?(cases, & &1.passed?),
      persistent_trust_store_complete?: false,
      key_rotation_complete?: false,
      revocation_lifecycle_complete?: false,
      trusted_delivery_claim_allowed?: false,
      blocked_claims: @blocked_claims,
      cases: cases,
      notes: [
        "Validation covers supplied in-memory policy semantics only.",
        "A successor key can be trusted only through an explicit operator policy entry.",
        "Persistent key storage, rotation UX, revocation sync, and trusted delivery remain blocked."
      ]
    }
  end

  @spec json_snapshot() :: map()
  def json_snapshot do
    snapshot()
    |> JSON.encode!()
    |> JSON.decode!()
  end

  defp run_cases do
    with {:ok, old_enrollment} <- enrollment("meshx-alpha", "old", 1_000),
         {:ok, new_enrollment} <- enrollment("meshx-alpha", "new", 2_000),
         {:ok, old_binding} <- LocalSecurityPeerEnrollment.to_binding(old_enrollment),
         {:ok, new_binding} <- LocalSecurityPeerEnrollment.to_binding(new_enrollment),
         {:ok, empty_policy} <- LocalSecurityOperatorTrustPolicy.new(),
         {:ok, old_trusted_policy} <-
           LocalSecurityOperatorTrustPolicy.put(empty_policy, old_binding, :trusted,
             updated_at: 1_100,
             reason: "operator trusted old key"
           ),
         {:ok, successor_trusted_policy} <-
           LocalSecurityOperatorTrustPolicy.put(old_trusted_policy, new_binding, :trusted,
             updated_at: 2_100,
             reason: "operator trusted successor key"
           ),
         {:ok, blocked_policy} <-
           LocalSecurityOperatorTrustPolicy.put(old_trusted_policy, old_binding, :blocked,
             updated_at: 2_200,
             reason: "operator blocked old key"
           ),
         {:ok, revoked_policy} <-
           LocalSecurityOperatorTrustPolicy.put(old_trusted_policy, old_binding, :revoked,
             updated_at: 2_300,
             reason: "operator revoked old key"
           ) do
      [
        policy_case(:new_key_starts_unknown, empty_policy, new_binding, :unknown),
        policy_case(:old_key_trust_does_not_transfer, old_trusted_policy, new_binding, :unknown),
        policy_case(
          :explicit_successor_key_can_be_trusted,
          successor_trusted_policy,
          new_binding,
          :trusted
        ),
        policy_case(:blocked_key_fails_closed, blocked_policy, old_binding, :blocked),
        policy_case(:revoked_key_fails_closed, revoked_policy, old_binding, :revoked),
        passive_rotation_case()
      ]
    else
      {:error, reason} -> [malformed_case(reason)]
    end
  end

  defp policy_case(id, policy, binding, expected_state) do
    case LocalSecurityOperatorTrustPolicy.evaluate(policy, binding) do
      {:ok, result} ->
        %{
          id: id,
          passed?: result.peer_trust_state == expected_state,
          expected_state: expected_state,
          actual_state: result.peer_trust_state,
          trusted_peer_state?: result.trusted_peer_state?,
          blocked_claims: @blocked_claims,
          notes: [
            "Trust lifecycle validation is scoped to peer_id plus key_id.",
            "This case does not persist trust or prove delivery."
          ]
        }

      {:error, reason} ->
        malformed_case(reason, id, expected_state)
    end
  end

  defp passive_rotation_case do
    result =
      LocalSecurityPeerEnrollment.reject_passive_observation(%{
        advertised_name: "meshx-alpha",
        sender_peer_hash: <<1::64>>,
        received_device_id: "AA:BB:CC:DD:EE:01"
      })

    %{
      id: :passive_observation_cannot_rotate_key,
      passed?: result == {:error, :passive_observation_not_enrollment},
      expected_state: :passive_observation_not_enrollment,
      actual_state: elem(result, 1),
      trusted_peer_state?: false,
      blocked_claims: @blocked_claims,
      notes: [
        "Passive BLE observations cannot create successor key trust.",
        "Operator-supplied enrollment remains required."
      ]
    }
  end

  defp enrollment(peer_id, label, enrolled_at) do
    {public_key, _private_key} = :crypto.generate_key(:eddsa, :ed25519)

    LocalSecurityPeerEnrollment.enroll(peer_id, public_key,
      enrolled_at: enrolled_at,
      label: label
    )
  end

  defp malformed_case(reason, id \\ :invalid_trust_lifecycle_case, expected_state \\ :unknown) do
    %{
      id: id,
      passed?: false,
      expected_state: expected_state,
      actual_state: reason,
      trusted_peer_state?: false,
      blocked_claims: @blocked_claims,
      notes: ["Trust lifecycle validation case could not execute."]
    }
  end
end
