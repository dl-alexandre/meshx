defmodule Mob.Node.BLE.LocalSecurityDecisionScenarioPlan do
  @moduledoc """
  Scenario plan for local BLE security decision outcomes.

  This plan makes the current unsigned-observation security decision explicit
  beside the blocked authenticated/trusted path. It is policy evidence only.
  It does not create keys, sign messages, persist trust, persist replay state,
  fetch envelopes, inspect hardware, route, ACK, retry, encrypt, authenticate,
  or run background work.
  """

  alias Mob.Node.BLE.{
    LocalSecurityIdentityValidationPlan,
    LocalSecurityReleaseEvidenceReview,
    LocalTrustPolicy
  }

  @allowed_decision_outcomes [
    :keep_unsigned_local_observation,
    :enable_authenticated_local_trust
  ]

  @spec snapshot() :: map()
  def snapshot do
    decision = LocalTrustPolicy.current_decision()
    validation_plan = LocalSecurityIdentityValidationPlan.snapshot()
    review = LocalSecurityReleaseEvidenceReview

    %{
      plan_version: 1,
      boundary: :local_security_decision_scenario_plan,
      status: :open,
      current_security_decision: decision,
      selected_decision_outcome: decision.decision_outcome,
      allowed_decision_outcomes: @allowed_decision_outcomes,
      authenticated_peer_identity_claim_allowed?: false,
      authenticated_message_claim_allowed?: false,
      trusted_message_claim_allowed?: false,
      trusted_delivery_claim_allowed?: false,
      fresh_message_claim_allowed?: false,
      validation_plan: validation_plan,
      decision_scenarios: decision_scenarios(review, validation_plan),
      review_commands: review_commands(),
      artifact_root: "artifacts/local-ble/<run-id>/security/",
      notes: [
        "This scenario plan is not security evidence by itself.",
        "keep_unsigned_local_observation is selected for the current advertisement-only local mesh mode.",
        "enable_authenticated_local_trust remains blocked until every security validation gate has operator-reviewed evidence.",
        "A local trusted-message decision would still not be trusted delivery, routed delivery, or guaranteed delivery."
      ]
    }
  end

  @spec json_snapshot() :: map()
  def json_snapshot do
    snapshot()
    |> JSON.encode!()
    |> JSON.decode!()
  end

  defp decision_scenarios(review, validation_plan) do
    [
      %{
        id: :keep_unsigned_local_observation,
        decision_outcome: :keep_unsigned_local_observation,
        status: :selected_for_current_validated_mode,
        security_mode_after_decision: :unsigned_local_ble_observations,
        authenticated_peer_identity_enabled?: false,
        authenticated_message_enabled?: false,
        trusted_message_enabled?: false,
        required_operator_evidence: [
          "Operator/release note preserves unsigned local observation wording.",
          "Release artifact references LocalSecurityEvidenceManifest.",
          "Authenticated identity, authenticated message, trusted message, freshness, and trusted delivery claims remain blocked."
        ],
        blocked_claims_called_out: review.required_blocked_claims(),
        review_section: :security_attachments,
        artifact_path: "artifacts/local-ble/<run-id>/security/release-review.md"
      },
      %{
        id: :enable_authenticated_local_trust,
        decision_outcome: :enable_authenticated_local_trust,
        status: :blocked,
        security_mode_after_decision: :authenticated_local_trusted_message,
        authenticated_peer_identity_enabled?: false,
        authenticated_message_enabled?: false,
        trusted_message_enabled?: false,
        required_operator_evidence: [
          "Product/security decision explicitly selects enable_authenticated_local_trust.",
          "Every LocalSecurityIdentityValidationPlan gate has supplied evidence.",
          "LocalSecurityReleaseEvidenceReview returns ready for the supplied metadata.",
          "Release wording still blocks delivery, routing, background, guaranteed-delivery, and hash-only beacon promotion overclaims."
        ],
        required_gates: Enum.map(validation_plan.gates, & &1.id),
        missing_evidence:
          validation_plan.gates |> Enum.flat_map(& &1.missing_evidence) |> Enum.uniq(),
        blocked_claims_called_out: review.required_blocked_claims(),
        review_section: :security_attachments,
        artifact_path: "artifacts/local-ble/<run-id>/security/release-review.md"
      }
    ]
  end

  defp review_commands do
    [
      "mix mob.node.local_security.release_review --template --out artifacts/local-ble/<run-id>/security/evidence.json",
      "mix mob.node.local_security.release_review --input artifacts/local-ble/<run-id>/security/evidence.json --json --out tmp/local-security-release-review.json"
    ]
  end
end
