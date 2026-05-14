defmodule MeshxMobileApp.BLE.LocalSecurityBeaconReferenceRisk do
  @moduledoc """
  Security classification for hash-only legacy beacon references.

  A valid `BeaconRef` is useful as a compact pointer, but its short hashes are
  not authenticated identity, authorship, freshness, or trust evidence. This
  module makes that boundary executable for release evidence and product copy.
  It does not fetch envelopes, verify signatures, manage keys, persist trust,
  persist replay state, route, ACK, retry, encrypt, or run background work.
  """

  alias MeshxMobileApp.BLE.BeaconRef

  @blocked_claims [
    :authenticated_peer_identity,
    :authenticated_message,
    :trusted_message,
    :trusted_delivery,
    :fresh_message,
    :guaranteed_delivery,
    :routed_delivery
  ]

  @spec classify(BeaconRef.t() | term()) :: map()
  def classify(%BeaconRef{} = ref) do
    case BeaconRef.validate(ref) do
      :ok -> pointer(ref)
      {:error, reason} -> invalid(reason)
    end
  end

  def classify(_ref), do: invalid(:invalid_beacon_ref)

  @spec snapshot() :: map()
  def snapshot do
    %{
      risk_version: 1,
      boundary: :hash_only_beacon_reference_security_risk,
      valid_beacon_ref_claim_allowed?: true,
      authenticated_peer_identity_claim_allowed?: false,
      authenticated_message_claim_allowed?: false,
      trusted_message_claim_allowed?: false,
      trusted_delivery_claim_allowed?: false,
      freshness_claim_allowed?: false,
      blocked_claims: @blocked_claims,
      required_before_trust: [
        :resolved_full_envelope,
        :peer_identity_binding,
        :message_authorship_proof,
        :replay_protection,
        :operator_or_policy_trust_decision
      ],
      notes: [
        "message_id_hash and sender_peer_hash are compact reference keys.",
        "Hash equality can match a later resolved envelope but cannot prove authorship by itself.",
        "A beacon ref can become authenticated only through LocalSecurityBeaconAuthentication after full-envelope resolution."
      ]
    }
  end

  @spec json_snapshot() :: map()
  def json_snapshot do
    snapshot()
    |> JSON.encode!()
    |> JSON.decode!()
  end

  defp pointer(ref) do
    %{
      status: :valid_pointer,
      valid_beacon_ref?: true,
      hash_reference_only?: true,
      authenticated_peer_identity?: false,
      authenticated_message?: false,
      trusted_message?: false,
      trusted_delivery_claim_allowed?: false,
      freshness_claim_allowed?: false,
      envelope_version: ref.envelope_version,
      payload_kind: ref.payload_kind,
      message_id_hash: ref.message_id_hash,
      sender_peer_hash: ref.sender_peer_hash,
      observed_at: ref.observed_at,
      received_device_id: ref.received_device_id,
      rssi: ref.rssi,
      blocked_claims: @blocked_claims,
      required_before_trust: snapshot().required_before_trust,
      notes: [
        "Valid beacon ref is a pointer, not a signed message.",
        "Sender peer hash is not authenticated peer identity.",
        "Observed timestamp is local observation time, not freshness proof."
      ]
    }
  end

  defp invalid(reason) do
    %{
      status: :invalid_reference,
      valid_beacon_ref?: false,
      hash_reference_only?: false,
      authenticated_peer_identity?: false,
      authenticated_message?: false,
      trusted_message?: false,
      trusted_delivery_claim_allowed?: false,
      freshness_claim_allowed?: false,
      reasons: [reason],
      blocked_claims: [:valid_beacon_ref | @blocked_claims],
      required_before_trust: snapshot().required_before_trust,
      notes: [
        "Invalid beacon refs are rejected before any trust or delivery classification."
      ]
    }
  end
end
