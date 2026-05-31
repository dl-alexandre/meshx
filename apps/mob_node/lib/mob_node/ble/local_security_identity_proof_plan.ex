defmodule Mob.Node.BLE.LocalSecurityIdentityProofPlan do
  @moduledoc """
  Proof plan for future authenticated local BLE message claims.

  The current advertisement-only inbox may show nearby observations, but it
  cannot call them trusted messages. This module maps each open security
  requirement to concrete future implementation gates and validation evidence.
  It does not implement crypto, signatures, key management, replay protection,
  trust storage, fetch transport, routing, ACKs, retries, persistence, or
  background work.
  """

  alias Mob.Node.BLE.LocalSecurityIdentityContract

  defmodule Gate do
    @moduledoc false

    @derive {JSON.Encoder,
             only: [
               :requirement_id,
               :status,
               :implementation_gates,
               :validation_evidence,
               :blocked_claims,
               :notes
             ]}
    @enforce_keys [
      :requirement_id,
      :status,
      :implementation_gates,
      :validation_evidence,
      :blocked_claims,
      :notes
    ]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            requirement_id: LocalSecurityIdentityContract.Requirement.id(),
            status: :planned,
            implementation_gates: [atom()],
            validation_evidence: [binary()],
            blocked_claims: [atom()],
            notes: [binary()]
          }
  end

  @proof_gates %{
    authenticated_peer_identity: %{
      implementation_gates: [
        :peer_key_material,
        :identity_key_binding,
        :device_rotation_survival,
        :identity_claim_source_upgrade
      ],
      validation_evidence: [
        "Fixture proving peer_id binds to authenticated key material.",
        "Replay proving device_id rotation does not change authenticated peer identity.",
        "Negative fixture proving passive advertised_name alone remains unauthenticated."
      ],
      blocked_claims: [:trusted_peer_identity, :trusted_message_delivery],
      notes: [
        "Current Identity.Claim values remain passive unless a future authenticated source emits."
      ]
    },
    message_authorship: %{
      implementation_gates: [
        :signature_or_equivalent_authorship_proof,
        :message_id_binding,
        :sender_peer_binding,
        :payload_binding,
        :envelope_version_binding
      ],
      validation_evidence: [
        "Positive fixture with a canonical MessageEnvelope and valid authorship proof.",
        "Negative fixtures for message_id, sender_peer_id, payload_kind, payload, and envelope_version tampering.",
        "Replay proof that authored envelopes still normalize through BridgeProtocol."
      ],
      blocked_claims: [:authenticated_message, :trusted_message_delivery],
      notes: ["Canonical envelope parsing is not authorship proof."]
    },
    replay_protection: %{
      implementation_gates: [
        :signed_timestamp_or_nonce,
        :bounded_replay_window,
        :seen_proof_cache,
        :expired_or_duplicate_rejection
      ],
      validation_evidence: [
        "Fixture proving duplicate signed envelope is rejected within the replay window.",
        "Fixture proving expired signed envelope is rejected.",
        "Bounded-state test proving replay cache retention and eviction are deterministic."
      ],
      blocked_claims: [:fresh_message, :trusted_message_delivery],
      notes: ["Inbox dedupe and seen_count are UI signals, not replay protection."]
    },
    trust_policy: %{
      implementation_gates: [
        :local_security_trust_model,
        :trust_transition_rules,
        :revocation_or_blocking_rules,
        :operator_visible_trust_reason
      ],
      validation_evidence: [
        "Fixture proving LocalSecurityTrustModel keeps unknown, untrusted, trusted, blocked, and revoked states distinct.",
        "Test proving a message cannot become trusted without identity, authorship, and replay evidence.",
        "Test proving trust revocation blocks future trusted-message presentation."
      ],
      blocked_claims: [:trusted_peer, :trusted_message_delivery],
      notes: ["Current LocalTrustPolicy is presentation gating, not a trust store."]
    },
    beacon_ref_authentication: %{
      implementation_gates: [
        :authenticated_beacon_pointer_or_resolution,
        :hash_sender_binding,
        :resolved_envelope_authorship_check,
        :hash_mismatch_rejection
      ],
      validation_evidence: [
        "Fixture proving a beacon ref resolves to a full authenticated envelope before trust evaluation.",
        "Negative fixture proving hash mismatch remains untrusted.",
        "Negative fixture proving a hash-only beacon is never promoted to trusted delivery."
      ],
      blocked_claims: [:trusted_beacon_ref, :trusted_message_delivery],
      notes: ["Legacy beacon refs remain pointers until resolution and authorship proof exist."]
    }
  }

  @spec gates() :: [Gate.t()]
  def gates do
    LocalSecurityIdentityContract.open_requirements()
    |> Enum.map(&gate/1)
  end

  @spec get(LocalSecurityIdentityContract.Requirement.id()) ::
          {:ok, Gate.t()} | {:error, :not_found}
  def get(requirement_id) do
    case Enum.find(gates(), &(&1.requirement_id == requirement_id)) do
      %Gate{} = gate -> {:ok, gate}
      nil -> {:error, :not_found}
    end
  end

  @spec snapshot() :: map()
  def snapshot do
    gates = gates()

    %{
      plan_version: 1,
      proof_boundary: :future_authenticated_local_ble_messages,
      gates: gates,
      open_gate_count: length(gates),
      trusted_delivery_claims_allowed?: false,
      notes: [
        "Every security identity gate is planned, not implemented.",
        "Advertisement-only observations remain displayable only as local evidence.",
        "Trusted-message delivery claims stay blocked until all gates have implementation and validation evidence."
      ]
    }
  end

  @spec json_snapshot() :: map()
  def json_snapshot do
    snapshot()
    |> JSON.encode!()
    |> JSON.decode!()
  end

  defp gate(%LocalSecurityIdentityContract.Requirement{id: id}) do
    data = Map.fetch!(@proof_gates, id)

    %Gate{
      requirement_id: id,
      status: :planned,
      implementation_gates: data.implementation_gates,
      validation_evidence: data.validation_evidence,
      blocked_claims: data.blocked_claims,
      notes: data.notes
    }
  end
end
