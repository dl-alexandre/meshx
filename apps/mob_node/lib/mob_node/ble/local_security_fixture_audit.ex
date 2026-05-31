defmodule Mob.Node.BLE.LocalSecurityFixtureAudit do
  @moduledoc """
  Fixture inventory for local BLE security and identity validation.

  This module audits the implementation-backed fixture coverage that already
  exists around the pure security boundaries. It does not create keys for the
  app, persist trust, persist replay state, fetch envelopes, route, ACK, retry,
  encrypt, or enable trusted-message or delivery claims.
  """

  alias Mob.Node.BLE.{
    LocalSecurityCryptoNegativeValidation,
    LocalSecurityIdentityValidationPlan
  }

  defmodule Fixture do
    @moduledoc false

    @derive {JSON.Encoder,
             only: [
               :id,
               :plan_gate_id,
               :status,
               :evidence,
               :missing_evidence,
               :blocked_claims,
               :notes
             ]}
    @enforce_keys [
      :id,
      :plan_gate_id,
      :status,
      :evidence,
      :missing_evidence,
      :blocked_claims,
      :notes
    ]
    defstruct @enforce_keys

    @type status :: :covered_current_boundary | :partial | :blocked

    @type t :: %__MODULE__{
            id: atom(),
            plan_gate_id: atom(),
            status: status(),
            evidence: [binary()],
            missing_evidence: [binary()],
            blocked_claims: [atom()],
            notes: [binary()]
          }
  end

  @spec fixtures() :: [Fixture.t()]
  def fixtures do
    [
      fixture(
        :supplied_peer_key_binding,
        :peer_key_enrollment,
        :partial,
        [
          "LocalSecurityPeerEnrollment records explicit operator-supplied peer_id to Ed25519 public key enrollment as untrusted identity evidence.",
          "Passive BLE observations are rejected as enrollment evidence.",
          "LocalSecurityPeerIdentityBinding binds a supplied peer_id to supplied Ed25519 public key material.",
          "Peer/key mismatch fixtures prevent a mismatched key from becoming trusted."
        ],
        [
          "Production operator-visible enrollment flow or equivalent authenticated identity source.",
          "Passive BLE names, device IDs, hashes, and beacon refs still need enrollment-negative fixtures."
        ],
        [:authenticated_peer_identity, :trusted_peer_identity]
      ),
      fixture(
        :authorship_proof_matrix,
        :authorship_fixture_matrix,
        :partial,
        [
          "LocalSecurityAuthorshipProof signs and verifies full MessageEnvelope values with supplied Ed25519 key material.",
          "Fixtures reject tampered message_id, sender_peer_id, payload_kind, payload bytes, envelope_version, signer mismatch, malformed signatures, and hash-only beacon refs.",
          "LocalSecurityCryptoNegativeValidation covers transport payload tamper and signature mismatch cases.",
          "Canonical replay fixtures reject message_id, sender_peer_id, recipient_peer_id, and transport payload divergence before trusted-message decisions."
        ],
        [
          "Release evidence tying the authorship matrix to operator-visible security wording."
        ],
        [:authenticated_message, :trusted_message, :trusted_delivery]
      ),
      fixture(
        :in_memory_replay_guard_matrix,
        :replay_state_lifecycle,
        :partial,
        [
          "LocalSecurityReplayProtection provides bounded in-memory duplicate rejection.",
          "LocalSecurityReplayLifecyclePolicy records replay state as memory-only and cleared on process restart.",
          "LocalSecurityReplayLifecycleValidation proves duplicate rejection, pruning, restart clearing, expiry, and beacon-ref rejection for the memory-only replay guard.",
          "Canonical replay and crypto negative fixtures reject duplicate proofs."
        ],
        [
          "Durable replay store policy if restart-surviving replay protection is required.",
          "Corruption, schema version, and release evidence fixtures for durable replay state."
        ],
        [:fresh_message, :trusted_message, :trusted_delivery]
      ),
      fixture(
        :operator_trust_policy_matrix,
        :trust_policy_lifecycle,
        :partial,
        [
          "LocalSecurityOperatorTrustPolicy covers trusted, unknown, blocked, and revoked peer/key states.",
          "LocalSecurityTrustLifecycleValidation proves new keys start unknown, old-key trust does not transfer, successor trust requires explicit policy, and blocked/revoked keys fail closed.",
          "Canonical replay fixtures require trusted peer/key policy before trusted-message promotion."
        ],
        [
          "Durable trust lifecycle implementation or explicit non-durable product decision.",
          "Production key rotation and revocation-sync fixtures."
        ],
        [:trusted_peer, :trusted_message, :trusted_delivery]
      ),
      fixture(
        :canonical_replay_security_matrix,
        :canonical_replay_integration,
        :covered_current_boundary,
        [
          "Replay-normalized ReceivedMessage fixtures can reach a local trusted-message decision with supplied proof, binding, replay state, and trusted policy.",
          "Negative fixtures reject missing trust policy, blocked policy, duplicate replay, envelope mismatch, transport payload mismatch, and beacon-only input."
        ],
        [
          "This remains a local trusted-message decision only; trusted delivery and real transport resolution remain blocked."
        ],
        [:trusted_delivery, :routed_delivery, :guaranteed_delivery]
      ),
      fixture(
        :beacon_pointer_authentication_matrix,
        :beacon_ref_authentication_integration,
        :partial,
        [
          "LocalSecurityBeaconAuthentication authenticates a beacon ref only after it matches a resolved trusted full envelope.",
          "Fixtures reject hash mismatch, unresolved/untrusted envelope decisions, malformed refs, and non-envelope inputs."
        ],
        [
          "Real full-envelope resolution transport feeding the beacon authentication boundary.",
          "Canonical replay fixture proving a hardware-observed beacon resolves to the trusted envelope."
        ],
        [:trusted_beacon_ref, :trusted_message, :trusted_delivery]
      ),
      fixture(
        :crypto_negative_claim_matrix,
        :negative_claim_review,
        :covered_current_boundary,
        [
          "Executable negative cases cover #{format_case_ids(LocalSecurityCryptoNegativeValidation.required_case_ids())}."
        ],
        [
          "Expanded implementation-backed negative fixtures for Android/iOS evidence reuse and future lifecycle transitions."
        ],
        [:authenticated_message, :trusted_message, :trusted_delivery]
      ),
      fixture(
        :security_release_artifact_review,
        :release_artifact_evidence,
        :blocked,
        [
          "LocalReleaseManifest and LocalProjectCompletionAudit keep trusted delivery and authenticated security wording blocked.",
          "LocalSecurityReleaseEvidenceReview defines required security attachments, plan-gate coverage, blocked claim callouts, and operator review."
        ],
        [
          "Release-candidate artifact bundle with security validation evidence.",
          "Operator release-note review for authenticated/trusted wording."
        ],
        [:trusted_delivery, :guaranteed_delivery, :routed_delivery]
      )
    ]
  end

  @spec snapshot() :: map()
  def snapshot do
    fixtures = fixtures()
    plan = LocalSecurityIdentityValidationPlan.snapshot()
    plan_gate_ids = Enum.map(plan.gates, & &1.id)
    fixture_gate_ids = Enum.map(fixtures, & &1.plan_gate_id)
    missing_plan_gate_ids = plan_gate_ids -- fixture_gate_ids

    %{
      audit_version: 1,
      boundary: :local_security_fixture_inventory,
      current_mode: :pure_security_boundaries_only,
      fixtures: fixtures,
      fixture_count: length(fixtures),
      covered_current_boundary_count:
        Enum.count(fixtures, &(&1.status == :covered_current_boundary)),
      partial_count: Enum.count(fixtures, &(&1.status == :partial)),
      blocked_count: Enum.count(fixtures, &(&1.status == :blocked)),
      plan_gate_count: length(plan_gate_ids),
      represented_plan_gate_count: length(Enum.uniq(fixture_gate_ids)),
      missing_plan_gate_ids: missing_plan_gate_ids,
      all_validation_plan_gates_represented?: missing_plan_gate_ids == [],
      authenticated_peer_identity_claim_allowed?: false,
      authenticated_message_claim_allowed?: false,
      trusted_message_claim_allowed?: false,
      trusted_delivery_claim_allowed?: false,
      replay_protection_claim_allowed?: false,
      blocked_claims: [
        :authenticated_peer_identity,
        :authenticated_message,
        :trusted_message,
        :trusted_delivery,
        :fresh_message
      ],
      notes: [
        "Fixture coverage is evidence inventory, not product security completion.",
        "Partial and blocked fixture groups keep LocalSecurityIdentityValidationPlan gates open.",
        "Trusted-message and trusted-delivery wording remain blocked for current local BLE observations."
      ]
    }
  end

  @spec json_snapshot() :: map()
  def json_snapshot do
    snapshot()
    |> JSON.encode!()
    |> JSON.decode!()
  end

  defp fixture(id, plan_gate_id, status, evidence, missing_evidence, blocked_claims) do
    %Fixture{
      id: id,
      plan_gate_id: plan_gate_id,
      status: status,
      evidence: evidence,
      missing_evidence: missing_evidence,
      blocked_claims: blocked_claims,
      notes: [
        "Fixture audit does not enable trusted delivery, routing, fetch, or background claims."
      ]
    }
  end

  defp format_case_ids(case_ids) do
    case_ids
    |> Enum.map(&Atom.to_string/1)
    |> Enum.join(", ")
  end
end
