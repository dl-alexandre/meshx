defmodule MeshxMobileApp.BLE.LocalSecurityAcceptance do
  @moduledoc """
  Acceptance boundary for local BLE security and identity claims.

  The current advertisement-only local mode can show useful observations,
  but it has no authenticated identity, authorship proof, replay protection,
  or trust-store transition. This module records which security boundaries
  are satisfied by current claim gating and which gates still block trusted
  message claims. It does not implement crypto, signatures, key management,
  replay storage, trust storage, fetch, routing, persistence, ACKs, retries,
  encryption, or background work.
  """

  alias MeshxMobileApp.BLE.{
    LocalSecurityIdentityContract,
    LocalSecurityCryptoNegativeValidation,
    LocalSecurityFixtureAudit,
    LocalSecurityIdentityNegativeValidation,
    LocalSecurityIdentityProofPlan,
    LocalSecurityIdentityValidationPlan,
    LocalSecurityPeerEnrollment,
    LocalSecurityReplayLifecyclePolicy,
    LocalSecurityReplayLifecycleValidation,
    LocalSecurityReleaseEvidenceReview,
    LocalSecurityTrustLifecyclePlan,
    LocalSecurityTrustLifecycleValidation,
    LocalSecurityTrustModel,
    LocalTrustPolicy
  }

  defmodule Gate do
    @moduledoc false

    @derive {JSON.Encoder,
             only: [
               :id,
               :status,
               :evidence,
               :missing,
               :blocked_claims,
               :notes
             ]}
    @enforce_keys [:id, :status, :evidence, :missing, :blocked_claims, :notes]
    defstruct @enforce_keys

    @type status :: :satisfied | :blocked

    @type t :: %__MODULE__{
            id: atom(),
            status: status(),
            evidence: [binary()],
            missing: [binary()],
            blocked_claims: [atom()],
            notes: [binary()]
          }
  end

  @blocked_claims [
    :authenticated_peer_identity,
    :authenticated_message,
    :trusted_message,
    :trusted_delivery,
    :fresh_message
  ]

  @spec gates(map()) :: [Gate.t()]
  def gates(snapshot \\ %{}) do
    contract = LocalSecurityIdentityContract.snapshot()
    proof_plan = LocalSecurityIdentityProofPlan.snapshot()
    trust_model = LocalSecurityTrustModel.snapshot()
    negative = LocalSecurityIdentityNegativeValidation.snapshot()
    trust_policy = LocalTrustPolicy.snapshot(Map.take(snapshot, [:trust_evidence]))

    [
      current_policy_gate(trust_policy),
      future_contract_gate(contract, proof_plan),
      trust_model_gate(trust_model),
      negative_validation_gate(negative),
      crypto_negative_validation_gate(),
      security_validation_plan_gate(),
      security_fixture_audit_gate(),
      peer_enrollment_boundary_gate(),
      authorship_verifier_gate(),
      peer_identity_binding_gate(),
      replay_guard_gate(),
      replay_lifecycle_policy_gate(),
      replay_lifecycle_validation_gate(),
      trusted_message_decision_gate(),
      canonical_replay_decision_gate(),
      operator_trust_policy_gate(),
      trust_lifecycle_plan_gate(),
      trust_lifecycle_validation_gate(),
      security_release_evidence_review_gate(),
      beacon_authentication_boundary_gate(),
      authenticated_identity_gate(contract),
      authorship_gate(contract),
      replay_protection_gate(contract),
      beacon_authentication_gate(contract)
    ]
  end

  @spec snapshot(map()) :: map()
  def snapshot(snapshot \\ %{}) do
    gates = gates(snapshot)

    %{
      acceptance_version: 1,
      boundary: :current_unsigned_local_ble_security,
      gates: gates,
      satisfied_count: Enum.count(gates, &(&1.status == :satisfied)),
      blocked_count: Enum.count(gates, &(&1.status == :blocked)),
      authenticated_peer_identity_claim_allowed?: false,
      trusted_message_claim_allowed?: false,
      trusted_delivery_claim_allowed?: false,
      replay_protection_claim_allowed?: false,
      blocked_claims: @blocked_claims,
      notes: [
        "Current local BLE observations are displayable as local evidence only.",
        "Hashes and beacon refs are lookup references, not authorship proof.",
        "Trusted-message claims remain blocked until identity, authorship, replay protection, trust policy, and beacon authentication gates have implementation-backed evidence."
      ]
    }
  end

  @spec json_snapshot(map()) :: map()
  def json_snapshot(snapshot \\ %{}) do
    snapshot(snapshot)
    |> JSON.encode!()
    |> JSON.decode!()
  end

  defp current_policy_gate(policy) do
    blocked? =
      policy.trusted_message_count == 0 and
        policy.delivery_claims_allowed? == false

    gate(
      :current_trust_policy,
      if(blocked?, do: :satisfied, else: :blocked),
      ["LocalTrustPolicy blocks trusted-message and delivery wording for current observations."],
      if(blocked?, do: [], else: ["Current trust policy allows a trusted or delivery claim."]),
      [:trusted_message, :trusted_delivery],
      ["The policy is presentation gating, not crypto or a trust store."]
    )
  end

  defp future_contract_gate(contract, proof_plan) do
    complete? = contract.open_requirement_count == proof_plan.open_gate_count

    gate(
      :future_security_contract,
      if(complete?, do: :satisfied, else: :blocked),
      [
        "LocalSecurityIdentityContract and LocalSecurityIdentityProofPlan enumerate the same open proof categories."
      ],
      if(complete?, do: [], else: ["Security contract and proof plan gate counts diverge."]),
      @blocked_claims,
      ["The contract/proof plan is necessary evidence, not implementation."]
    )
  end

  defp trust_model_gate(model) do
    blocked? =
      model.current_observations_trusted? == false and
        model.delivery_claims_allowed? == false

    gate(
      :trust_transition_model,
      if(blocked?, do: :satisfied, else: :blocked),
      [
        "LocalSecurityTrustModel defines future trust states while keeping current observations untrusted."
      ],
      if(blocked?, do: [], else: ["Trust model allows current observations to be trusted."]),
      [:trusted_message, :trusted_delivery],
      ["The model evaluates future proof inputs; it does not verify signatures."]
    )
  end

  defp negative_validation_gate(negative) do
    blocked? =
      negative.trusted_claims_allowed? == false and
        negative.delivery_claims_allowed? == false

    gate(
      :negative_security_validation,
      if(blocked?, do: :satisfied, else: :blocked),
      [
        "LocalSecurityIdentityNegativeValidation blocks unsigned, hash-only, gossiped, stale, and passive-label trust claims."
      ],
      if(blocked?,
        do: [],
        else: ["Security negative validation allows a trusted or delivery claim."]
      ),
      negative.blocked_claims,
      [
        "Negative validation must be replaced by crypto-backed positive and negative fixtures in future work."
      ]
    )
  end

  defp crypto_negative_validation_gate do
    gate(
      :crypto_negative_validation_boundary,
      :satisfied,
      [
        "LocalSecurityCryptoNegativeValidation runs executable crypto/replay negative cases for tamper, replay, key mismatch, non-matching trusted policy, blocked/revoked policy, beacon-ref promotion, passive labels, and stale refs."
      ],
      [],
      LocalSecurityCryptoNegativeValidation.required_case_ids(),
      [
        "The validation boundary blocks over-promotion; it does not create keys, persist trust, persist replay state, or claim delivery.",
        "Caller-supplied fixtures still need expansion before the security identity item can close."
      ]
    )
  end

  defp security_validation_plan_gate do
    plan = LocalSecurityIdentityValidationPlan.snapshot()

    required_gates = [
      :peer_key_enrollment,
      :authorship_fixture_matrix,
      :replay_state_lifecycle,
      :trust_policy_lifecycle,
      :canonical_replay_integration,
      :beacon_ref_authentication_integration,
      :release_artifact_evidence,
      :negative_claim_review
    ]

    present_gates = Enum.map(plan.gates, & &1.id)
    missing_gates = Enum.reject(required_gates, &(&1 in present_gates))

    satisfied? =
      missing_gates == [] and
        plan.authenticated_peer_identity_claim_allowed? == false and
        plan.authenticated_message_claim_allowed? == false and
        plan.trusted_message_claim_allowed? == false and
        plan.trusted_delivery_claim_allowed? == false and
        plan.replay_protection_claim_allowed? == false

    gate(
      :security_identity_validation_plan,
      if(satisfied?, do: :satisfied, else: :blocked),
      [
        "LocalSecurityIdentityValidationPlan records peer key enrollment, authorship fixtures, replay lifecycle, trust lifecycle, canonical replay, beacon authentication, release evidence, and negative claim review gates."
      ],
      Enum.map(missing_gates, &"Missing security validation gate #{inspect(&1)}."),
      @blocked_claims,
      ["The plan structures security evidence without enabling trusted-message claims."]
    )
  end

  defp security_fixture_audit_gate do
    audit = LocalSecurityFixtureAudit.snapshot()

    satisfied? =
      audit.all_validation_plan_gates_represented? and
        audit.trusted_message_claim_allowed? == false and
        audit.trusted_delivery_claim_allowed? == false

    gate(
      :security_fixture_audit,
      if(satisfied?, do: :satisfied, else: :blocked),
      [
        "LocalSecurityFixtureAudit inventories implementation-backed positive and negative fixture coverage for every LocalSecurityIdentityValidationPlan gate."
      ],
      Enum.map(audit.missing_plan_gate_ids, &"Missing fixture coverage for #{inspect(&1)}."),
      audit.blocked_claims,
      [
        "Fixture inventory does not close partial security gates or enable trusted-message claims.",
        "Partial fixture groups still require enrollment, durable trust/replay lifecycle, real beacon resolution, and release evidence."
      ]
    )
  end

  defp peer_enrollment_boundary_gate do
    enrollment = LocalSecurityPeerEnrollment.snapshot()

    satisfied? =
      enrollment.passive_observation_enrollment_allowed? == false and
        enrollment.trusted_message_claim_allowed? == false and
        enrollment.trusted_delivery_claim_allowed? == false

    gate(
      :peer_enrollment_boundary,
      if(satisfied?, do: :satisfied, else: :blocked),
      [
        "LocalSecurityPeerEnrollment records explicit operator-supplied peer/key enrollment while rejecting passive BLE observations as enrollment evidence."
      ],
      if(satisfied?,
        do: [],
        else: ["Peer enrollment boundary allows passive enrollment or trusted/delivery claims."]
      ),
      enrollment.blocked_claims,
      [
        "Enrollment is an in-memory proof boundary, not persistent trust lifecycle.",
        "Explicit operator trust policy, authorship verification, and replay protection are still required before local trusted-message decisions."
      ]
    )
  end

  defp authorship_verifier_gate do
    gate(
      :authorship_verifier_boundary,
      :satisfied,
      [
        "LocalSecurityAuthorshipProof defines domain-separated Ed25519 authorship verification for full MessageEnvelope values."
      ],
      [],
      [:trusted_message, :trusted_delivery],
      [
        "The verifier needs supplied key material and does not manage trust, replay state, or beacon-ref authentication.",
        "A verified authorship proof alone is not enough for trusted delivery."
      ]
    )
  end

  defp peer_identity_binding_gate do
    gate(
      :peer_identity_binding_boundary,
      :satisfied,
      [
        "LocalSecurityPeerIdentityBinding binds peer_id to supplied Ed25519 public key material and verifies matching authorship proofs."
      ],
      [],
      [:trusted_peer_identity, :trusted_message, :trusted_delivery],
      [
        "The binding is explicit supplied evidence, not key discovery, key persistence, revocation, replay protection, or a trust store.",
        "A valid binding plus authorship proof still does not authenticate hash-only beacon refs or claim delivery."
      ]
    )
  end

  defp replay_guard_gate do
    gate(
      :replay_guard_boundary,
      :satisfied,
      [
        "LocalSecurityReplayProtection provides a bounded in-memory replay guard for verified full-envelope proofs."
      ],
      [],
      [:fresh_message, :trusted_message, :trusted_delivery],
      [
        "The guard needs verified full-envelope proofs and does not persist replay state.",
        "Replay protection evidence alone is not trusted delivery and does not authenticate beacon refs."
      ]
    )
  end

  defp replay_lifecycle_policy_gate do
    policy = LocalSecurityReplayLifecyclePolicy.snapshot()

    satisfied? =
      policy.replay_state_mode == :memory_only and
        policy.durable_replay_state_allowed? == false and
        policy.trusted_delivery_claim_allowed? == false

    gate(
      :replay_lifecycle_policy_boundary,
      if(satisfied?, do: :satisfied, else: :blocked),
      [
        "LocalSecurityReplayLifecyclePolicy records replay state as memory-only and cleared on process restart."
      ],
      if(satisfied?,
        do: [],
        else: ["Replay lifecycle policy allows durable replay or trusted delivery claims."]
      ),
      policy.blocked_claims,
      [
        "Replay lifecycle policy is a current limitation boundary.",
        "Durable replay state requires a future store policy, pruning, restart restore, corruption, and release evidence."
      ]
    )
  end

  defp replay_lifecycle_validation_gate do
    validation = LocalSecurityReplayLifecycleValidation.snapshot()

    satisfied? =
      validation.all_required_cases_present? and
        validation.all_cases_passed? and
        validation.durable_replay_state_allowed? == false and
        validation.trusted_delivery_claim_allowed? == false

    gate(
      :replay_lifecycle_validation_boundary,
      if(satisfied?, do: :satisfied, else: :blocked),
      [
        "LocalSecurityReplayLifecycleValidation proves duplicate rejection, pruning, restart clearing, expiry, and beacon-ref rejection for the memory-only replay guard."
      ],
      if(satisfied?,
        do: [],
        else: ["Replay lifecycle validation has missing or failing cases."]
      ),
      validation.blocked_claims,
      [
        "Validation does not persist replay state or prove trusted delivery.",
        "Restart-surviving replay protection remains blocked."
      ]
    )
  end

  defp trusted_message_decision_gate do
    gate(
      :trusted_message_decision_boundary,
      :satisfied,
      [
        "LocalSecurityTrustedMessageDecision combines peer binding, authorship, replay protection, and explicit peer trust state for full envelopes."
      ],
      [],
      [:trusted_delivery, :routed_delivery, :guaranteed_delivery],
      [
        "The decision boundary is full-envelope only and does not authenticate beacon refs.",
        "A trusted local message decision is not delivery, routing, persistence, or background evidence."
      ]
    )
  end

  defp canonical_replay_decision_gate do
    gate(
      :canonical_replay_decision_boundary,
      :satisfied,
      [
        "LocalSecurityCanonicalReplayDecision evaluates replay-normalized ReceivedMessage events with supplied proof, binding, replay state, and explicit peer trust state."
      ],
      [],
      [:trusted_delivery, :routed_delivery, :guaranteed_delivery],
      [
        "Canonical replay integration is full ReceivedMessage only and rejects hash-only beacon refs.",
        "A trusted replay-normalized message decision is not delivery, routing, persistence, or background evidence."
      ]
    )
  end

  defp operator_trust_policy_gate do
    gate(
      :operator_trust_policy_boundary,
      :satisfied,
      [
        "LocalSecurityOperatorTrustPolicy scopes explicit operator trust to a supplied peer_id and Ed25519 key_id binding."
      ],
      [],
      [:trusted_message, :trusted_delivery, :routed_delivery],
      [
        "Operator trust policy is supplied evidence, not key discovery, persistent trust storage, or revocation sync.",
        "A trusted peer/key policy entry still requires authorship verification and replay protection before trusted-message wording."
      ]
    )
  end

  defp trust_lifecycle_plan_gate do
    gate(
      :trust_lifecycle_plan_boundary,
      :satisfied,
      [
        "LocalSecurityTrustLifecyclePlan records persistent key/trust lifecycle gates for enrollment, storage, rotation, revocation, replay state, and release audit export."
      ],
      [],
      LocalSecurityTrustLifecyclePlan.snapshot().blocked_claims,
      [
        "The lifecycle plan is a contract for future durable trust behavior, not a persistent trust store.",
        "Trusted-delivery claims remain blocked even if local trust lifecycle gates later pass."
      ]
    )
  end

  defp trust_lifecycle_validation_gate do
    validation = LocalSecurityTrustLifecycleValidation.snapshot()

    satisfied? =
      validation.all_required_cases_present? and
        validation.all_cases_passed? and
        validation.trusted_delivery_claim_allowed? == false

    gate(
      :trust_lifecycle_validation_boundary,
      if(satisfied?, do: :satisfied, else: :blocked),
      [
        "LocalSecurityTrustLifecycleValidation proves supplied-policy key rotation and revocation cases fail closed without persistence or delivery claims."
      ],
      if(satisfied?,
        do: [],
        else: ["Trust lifecycle validation has missing or failing cases."]
      ),
      validation.blocked_claims,
      [
        "Validation covers pure supplied policy semantics only.",
        "Persistent trust store, production key rotation, revocation sync, and trusted delivery remain blocked."
      ]
    )
  end

  defp security_release_evidence_review_gate do
    gate(
      :security_release_evidence_review_boundary,
      :satisfied,
      [
        "LocalSecurityReleaseEvidenceReview defines the operator-reviewed security evidence package required before authenticated/trusted wording can be considered."
      ],
      [],
      LocalSecurityReleaseEvidenceReview.required_blocked_claims(),
      [
        "The review contract is packaging evidence only; it does not close security validation gates by itself.",
        "Trusted-message and trusted-delivery claims remain blocked for current local BLE observations."
      ]
    )
  end

  defp beacon_authentication_boundary_gate do
    gate(
      :beacon_authentication_boundary,
      :satisfied,
      [
        "LocalSecurityBeaconAuthentication authenticates legacy beacon refs only after they match a resolved trusted full envelope."
      ],
      [],
      [:trusted_beacon_ref, :trusted_delivery, :routed_delivery],
      [
        "Hash-only beacon refs remain untrusted until full-envelope resolution and trusted-message decision evidence exist.",
        "Beacon authentication is pointer authentication, not message delivery."
      ]
    )
  end

  defp authenticated_identity_gate(contract) do
    requirement_gate(contract, :authenticated_peer_identity, [
      :authenticated_peer_identity,
      :trusted_message,
      :trusted_delivery
    ])
  end

  defp authorship_gate(contract) do
    requirement_gate(contract, :message_authorship, [
      :authenticated_message,
      :trusted_message,
      :trusted_delivery
    ])
  end

  defp replay_protection_gate(contract) do
    requirement_gate(contract, :replay_protection, [
      :fresh_message,
      :trusted_message,
      :trusted_delivery
    ])
  end

  defp beacon_authentication_gate(contract) do
    requirement_gate(contract, :beacon_ref_authentication, [
      :trusted_beacon_ref,
      :trusted_message,
      :trusted_delivery
    ])
  end

  defp requirement_gate(contract, id, blocked_claims) do
    requirement = Enum.find(contract.requirements, &(&1.id == id))

    gate(
      id,
      :blocked,
      [],
      requirement.required_evidence ++ [requirement.current_gap],
      blocked_claims,
      requirement.notes
    )
  end

  defp gate(id, status, evidence, missing, blocked_claims, notes) do
    %Gate{
      id: id,
      status: status,
      evidence: evidence,
      missing: missing,
      blocked_claims: blocked_claims,
      notes: notes
    }
  end
end
