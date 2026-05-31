defmodule Mob.Node.BLE.LocalSecurityIdentityValidationPlan do
  @moduledoc """
  Validation plan for authenticated local BLE security claims.

  The current stack has pure boundaries for authorship proofs, peer/key
  binding, replay protection, operator trust policy, trusted-message
  decisions, beacon authentication, and crypto negative cases. This module
  records the remaining implementation-backed evidence required before MeshX
  can claim authenticated peer identity, authenticated messages, trusted
  messages, or replay-protected local observations. It does not create keys,
  persist trust, persist replay state, fetch envelopes, route, ACK, retry,
  encrypt, or run background work.
  """

  defmodule Gate do
    @moduledoc false

    @derive {JSON.Encoder,
             only: [
               :id,
               :status,
               :required_evidence,
               :missing_evidence,
               :blocked_claims,
               :notes
             ]}
    @enforce_keys [
      :id,
      :status,
      :required_evidence,
      :missing_evidence,
      :blocked_claims,
      :notes
    ]
    defstruct @enforce_keys

    @type status :: :blocked

    @type t :: %__MODULE__{
            id: atom(),
            status: status(),
            required_evidence: [binary()],
            missing_evidence: [binary()],
            blocked_claims: [atom()],
            notes: [binary()]
          }
  end

  @spec gates() :: [Gate.t()]
  def gates do
    [
      gate(
        :peer_key_enrollment,
        [
          "Operator-visible peer_id to Ed25519 key enrollment flow or equivalent authenticated identity source.",
          "Fixtures proving passive advertised names cannot enroll trusted peer identity."
        ],
        [
          "Persistent or supplied key enrollment decision and evidence.",
          "Positive and negative fixtures for authenticated peer identity enrollment."
        ],
        [:authenticated_peer_identity, :trusted_peer_identity],
        ["Peer identity cannot be inferred from BLE names, device IDs, hashes, or beacon refs."]
      ),
      gate(
        :authorship_fixture_matrix,
        [
          "Canonical full MessageEnvelope fixture with valid authorship proof.",
          "Tamper fixtures for message_id, sender_peer_id, payload_kind, payload, and envelope_version."
        ],
        [
          "Release evidence tying authorship proof coverage to operator-reviewed security wording."
        ],
        [:authenticated_message, :trusted_message],
        [
          "LocalSecurityAuthorshipProofTest covers positive Ed25519 authorship plus message_id, sender_peer_id, payload_kind, payload, envelope_version, signer mismatch, malformed signature, and hash-only beacon-ref negative cases.",
          "LocalSecurityCanonicalReplayDecisionTest rejects message_id, sender_peer_id, recipient_peer_id, and transport payload divergence before trusted-message decisions.",
          "Canonical envelope parsing remains separate from proof of authorship."
        ]
      ),
      gate(
        :replay_state_lifecycle,
        [
          "Replay window, retention, pruning, duplicate rejection, expiry, and restart policy.",
          "Evidence deciding whether replay state remains in memory or becomes durable."
        ],
        [
          "Durable replay-state product decision if restart-surviving replay protection is required.",
          "Release evidence tying memory-only replay lifecycle validation to operator-reviewed security wording."
        ],
        [:fresh_message, :trusted_message],
        [
          "LocalSecurityReplayLifecycleValidation proves duplicate rejection, pruning, restart clearing, expiry, and beacon-ref rejection for memory-only replay state.",
          "In-memory replay guard evidence is not persistent replay lifecycle evidence."
        ]
      ),
      gate(
        :trust_policy_lifecycle,
        [
          "Trust transition fixtures for unknown, untrusted, trusted, blocked, and revoked peer/key bindings.",
          "Key rotation and revocation fixtures proving trust does not transfer implicitly."
        ],
        [
          "Durable trust lifecycle implementation or explicit non-durable product decision.",
          "Release evidence tying supplied trust lifecycle validation to operator-reviewed security wording."
        ],
        [:trusted_peer, :trusted_message],
        [
          "LocalSecurityTrustLifecycleValidation covers unknown, trusted successor, blocked, revoked, non-transfer, and passive-observation cases.",
          "Operator trust policy is supplied evidence today, not a persistent trust store."
        ]
      ),
      gate(
        :canonical_replay_integration,
        [
          "Replay-normalized ReceivedMessage fixture that reaches trusted-message decision with supplied proof, binding, replay state, and trusted peer state.",
          "Replay-normalized negative fixtures for missing proof, missing binding, stale replay, blocked policy, and beacon-only input."
        ],
        [
          "Release evidence tying canonical replay fixture coverage to operator-reviewed security wording.",
          "Full security acceptance evidence proving canonical replay stays local trusted-message only and never becomes trusted delivery."
        ],
        [:trusted_message, :trusted_delivery],
        [
          "LocalSecurityCanonicalReplayDecisionTest covers positive trusted-message decisions and negative mismatch, duplicate, blocked-policy, and beacon-only cases.",
          "Trusted replay decisions remain local trusted-message decisions, not delivery evidence."
        ]
      ),
      gate(
        :beacon_ref_authentication_integration,
        [
          "Fixture resolving a legacy beacon ref to a trusted full envelope before pointer authentication.",
          "Negative fixtures for hash mismatch, unresolved beacon, and trusted-policy mismatch."
        ],
        [
          "Full-envelope resolution evidence feeding LocalSecurityBeaconAuthentication.",
          "Beacon authentication fixtures after real resolution transport exists."
        ],
        [:trusted_beacon_ref, :trusted_message, :trusted_delivery],
        ["Hash-only beacon refs cannot authenticate themselves."]
      ),
      gate(
        :release_artifact_evidence,
        [
          "Release manifest entries for key enrollment, authorship, replay lifecycle, trust lifecycle, canonical replay, and beacon authentication evidence.",
          "Operator review that trusted-message wording remains local and does not claim delivery."
        ],
        [
          "Release-candidate artifact bundle with security validation evidence.",
          "Operator release-note review for authenticated/trusted wording."
        ],
        [:trusted_delivery, :guaranteed_delivery, :routed_delivery],
        ["Security evidence must remain separate from delivery, routing, and background claims."]
      ),
      gate(
        :negative_claim_review,
        [
          "Implementation-backed negative fixtures for tamper, replay, key mismatch, blocked/revoked policy, hash-only beacon promotion, passive labels, stale refs, and future Android/iOS evidence reuse.",
          "Regression evidence that blocked trusted/delivery claims stay blocked as security implementation grows."
        ],
        [
          "Expanded implementation-backed crypto negative fixture matrix.",
          "Regression evidence for every blocked trusted/delivery claim."
        ],
        [:trusted_message, :trusted_delivery, :authenticated_message],
        ["Negative validation must remain executable as positive trust paths expand."]
      )
    ]
  end

  @spec snapshot() :: map()
  def snapshot do
    gates = gates()

    %{
      plan_version: 1,
      boundary: :authenticated_local_ble_security_validation_plan,
      current_mode: :unsigned_local_ble_observations,
      authenticated_peer_identity_claim_allowed?: false,
      authenticated_message_claim_allowed?: false,
      trusted_message_claim_allowed?: false,
      trusted_delivery_claim_allowed?: false,
      replay_protection_claim_allowed?: false,
      gate_count: length(gates),
      blocked_gate_count: Enum.count(gates, &(&1.status == :blocked)),
      gates: gates,
      blocked_claims: [
        :authenticated_peer_identity,
        :authenticated_message,
        :trusted_message,
        :trusted_delivery,
        :fresh_message
      ],
      notes: [
        "Current BLE observations remain local unsigned evidence.",
        "Existing crypto boundaries require supplied key, proof, trust, and replay inputs.",
        "This plan adds evidence gates only; it does not enable trusted-message or delivery claims."
      ]
    }
  end

  @spec json_snapshot() :: map()
  def json_snapshot do
    snapshot()
    |> JSON.encode!()
    |> JSON.decode!()
  end

  defp gate(id, required_evidence, missing_evidence, blocked_claims, notes) do
    %Gate{
      id: id,
      status: :blocked,
      required_evidence: required_evidence,
      missing_evidence: missing_evidence,
      blocked_claims: blocked_claims,
      notes: notes
    }
  end
end
