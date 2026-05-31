defmodule Mob.Node.BLE.LocalSecurityTrustModel do
  @moduledoc """
  Pure trust-transition model for future authenticated local BLE messages.

  The model defines the evidence required before a local observation can be
  presented as trusted. It evaluates evidence that a future crypto/identity
  layer would provide; it does not verify signatures, manage keys, store trust,
  persist replay state, resolve beacon refs, route, fetch, ACK, retry, encrypt,
  or run background work.
  """

  alias Mob.Node.BLE.LocalTrustPolicy

  @peer_states [:unknown, :untrusted, :trusted, :blocked, :revoked]

  @base_required [
    :authenticated_peer_identity,
    :message_authorship,
    :replay_protection,
    :trusted_peer_state
  ]

  @ref_required [
    :full_envelope_resolution,
    :hash_sender_binding | @base_required
  ]

  @blocked_claims [
    :trusted_message,
    :trusted_delivery,
    :authenticated_peer_identity,
    :fresh_message
  ]

  @type peer_state :: :unknown | :untrusted | :trusted | :blocked | :revoked
  @type item_state :: :full_message | :unresolved_ref | :gossiped_ref | :stale_ref | atom()

  @type evaluation :: %{
          required(:item_state) => item_state(),
          required(:peer_trust_state) => peer_state(),
          required(:required_evidence) => [atom()],
          required(:provided_evidence) => [atom()],
          required(:missing_evidence) => [atom()],
          required(:trusted_message?) => boolean(),
          required(:delivery_claim_allowed?) => boolean(),
          required(:blocked_claims) => [atom()],
          required(:reasons) => [atom()]
        }

  @spec peer_states() :: [peer_state()]
  def peer_states, do: @peer_states

  @spec snapshot() :: map()
  def snapshot do
    %{
      model_version: 1,
      boundary: :future_authenticated_local_ble_trust,
      peer_states: @peer_states,
      full_message_required_evidence: @base_required,
      beacon_ref_required_evidence: @ref_required,
      current_observations_trusted?: false,
      delivery_claims_allowed?: false,
      blocked_claims: @blocked_claims,
      notes: [
        "This is a trust-transition model, not crypto implementation.",
        "Current local BLE observations do not provide the evidence required by this model.",
        "Hash-only beacon refs require full-envelope resolution and sender/hash binding before trust evaluation."
      ]
    }
  end

  @spec json_snapshot() :: map()
  def json_snapshot do
    snapshot()
    |> JSON.encode!()
    |> JSON.decode!()
  end

  @spec evaluate(LocalTrustPolicy.Decision.t() | map(), map() | keyword()) :: evaluation()
  def evaluate(item, proof \\ %{})

  def evaluate(%LocalTrustPolicy.Decision{} = decision, proof) do
    evaluate(%{item_state: decision.item_state}, proof)
  end

  def evaluate(%{item_state: item_state}, proof) do
    proof = normalize_proof(proof)
    peer_state = Map.get(proof, :peer_trust_state, :unknown)
    required = required_evidence(item_state)
    provided = provided_evidence(proof)
    missing = required -- provided
    reasons = reasons(item_state, peer_state, missing)

    trusted? = peer_state == :trusted and missing == []

    %{
      item_state: item_state,
      peer_trust_state: peer_state,
      required_evidence: required,
      provided_evidence: provided,
      missing_evidence: missing,
      trusted_message?: trusted?,
      delivery_claim_allowed?: trusted?,
      blocked_claims: if(trusted?, do: [], else: @blocked_claims),
      reasons: reasons
    }
  end

  def evaluate(_item, proof), do: evaluate(%{item_state: :unknown}, proof)

  defp normalize_proof(proof) when is_list(proof), do: Map.new(proof)
  defp normalize_proof(%{} = proof), do: proof
  defp normalize_proof(_proof), do: %{}

  defp required_evidence(:full_message), do: @base_required
  defp required_evidence(:unresolved_ref), do: @ref_required
  defp required_evidence(:gossiped_ref), do: @ref_required
  defp required_evidence(:stale_ref), do: @ref_required ++ [:fresh_observation]
  defp required_evidence(_item_state), do: @base_required

  defp provided_evidence(proof) do
    [
      flag(proof, :authenticated_peer_identity, :authenticated_peer_identity?),
      flag(proof, :message_authorship, :message_authorship?),
      flag(proof, :replay_protection, :replay_protection?),
      flag(proof, :full_envelope_resolution, :full_envelope_resolution?),
      flag(proof, :hash_sender_binding, :hash_sender_binding?),
      flag(proof, :fresh_observation, :fresh_observation?),
      if(Map.get(proof, :peer_trust_state) == :trusted, do: :trusted_peer_state)
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp flag(proof, evidence, key) do
    if Map.get(proof, key) == true, do: evidence
  end

  defp reasons(_item_state, peer_state, _missing) when peer_state in [:blocked, :revoked] do
    [:"peer_#{peer_state}"]
  end

  defp reasons(item_state, _peer_state, missing)
       when item_state in [:unresolved_ref, :gossiped_ref] do
    [:hash_reference_not_authorship | missing]
  end

  defp reasons(:stale_ref, _peer_state, missing), do: [:stale_reference | missing]
  defp reasons(_item_state, _peer_state, missing), do: missing
end
