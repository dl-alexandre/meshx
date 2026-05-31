defmodule Mob.Node.BLE.LocalSecurityOperatorCapturePlan do
  @moduledoc """
  Operator capture plan for local security release evidence.

  The plan turns `LocalSecurityReleaseEvidenceReview` gates into concrete
  artifact slots that can be filled before authenticated or trusted wording is
  considered. It does not persist keys, persist trust, persist replay state,
  fetch envelopes, inspect hardware, route, ACK, retry, encrypt, authenticate,
  or run background work.
  """

  alias Mob.Node.BLE.{
    LocalSecurityIdentityValidationPlan,
    LocalSecurityReleaseEvidenceReview,
    LocalTrustPolicy
  }

  @spec snapshot() :: map()
  def snapshot do
    review = LocalSecurityReleaseEvidenceReview
    decision = LocalTrustPolicy.current_decision()

    %{
      plan_version: 1,
      boundary: :local_security_operator_capture_plan,
      status: :open,
      current_security_decision: current_security_decision(decision),
      current_mode: :unsigned_local_ble_observations,
      security_release_evidence_complete?: false,
      authenticated_peer_identity_claim_allowed?: false,
      authenticated_message_claim_allowed?: false,
      trusted_message_claim_allowed?: false,
      trusted_delivery_claim_allowed?: false,
      fresh_message_claim_allowed?: false,
      validation_plan: LocalSecurityIdentityValidationPlan.snapshot(),
      required_plan_gate_ids: review.required_plan_gate_ids(),
      required_evidence_types: review.required_evidence_types(),
      required_blocked_claims: review.required_blocked_claims(),
      required_gate_blocked_claims: review.required_gate_blocked_claims(),
      capture_sections: capture_sections(review),
      review_commands: review_commands(),
      artifact_root: "artifacts/local-ble/<run-id>/security/",
      notes: [
        "This plan is an operator capture checklist, not evidence by itself.",
        "The current selected decision is keep_unsigned_local_observation.",
        "Hash-only beacon refs remain pointers until resolved trusted full envelopes exist.",
        "Authenticated identity, authenticated message, trusted message, trusted delivery, and freshness claims remain blocked."
      ]
    }
  end

  @spec json_snapshot() :: map()
  def json_snapshot do
    snapshot()
    |> JSON.encode!()
    |> JSON.decode!()
  end

  defp current_security_decision(decision) do
    %{
      decision_outcome: decision.decision_outcome,
      decision_status: decision.decision_status,
      authenticated_peer_identity_enabled?: false,
      authenticated_message_enabled?: false,
      trusted_message_claim_allowed?: false,
      trusted_delivery_claim_allowed?: false
    }
  end

  defp capture_sections(review) do
    gate_claims = review.required_gate_blocked_claims()

    Enum.map(review.required_plan_gate_ids(), fn gate_id ->
      section(
        review,
        gate_claims,
        gate_id,
        artifact_path(gate_id),
        notes(gate_id)
      )
    end)
  end

  defp section(review, gate_claims, gate_id, artifact_path, notes) do
    %{
      id: gate_id,
      review_section: :security_attachments,
      artifact_path: artifact_path,
      evidence_type: Map.fetch!(review.required_evidence_types(), gate_id),
      required_entries: [
        :artifact_id,
        :path,
        :source,
        :plan_gate_ids,
        :evidence_types_by_gate,
        :blocked_claims_called_out,
        :operator_reviewed?
      ],
      blocked_claims_called_out: review.required_blocked_claims(),
      gate_specific_blocked_claims_called_out: Map.get(gate_claims, gate_id, []),
      notes: notes
    }
  end

  defp artifact_path(:peer_key_enrollment),
    do: "artifacts/local-ble/<run-id>/security/peer-key-enrollment.md"

  defp artifact_path(:authorship_fixture_matrix),
    do: "artifacts/local-ble/<run-id>/security/authorship-fixtures.md"

  defp artifact_path(:replay_state_lifecycle),
    do: "artifacts/local-ble/<run-id>/security/replay-lifecycle.md"

  defp artifact_path(:trust_policy_lifecycle),
    do: "artifacts/local-ble/<run-id>/security/trust-lifecycle.md"

  defp artifact_path(:canonical_replay_integration),
    do: "artifacts/local-ble/<run-id>/security/canonical-replay.md"

  defp artifact_path(:beacon_ref_authentication_integration),
    do: "artifacts/local-ble/<run-id>/security/beacon-authentication.md"

  defp artifact_path(:release_artifact_evidence),
    do: "artifacts/local-ble/<run-id>/security/release-review.md"

  defp artifact_path(:negative_claim_review),
    do: "artifacts/local-ble/<run-id>/security/negative-claims.md"

  defp notes(:peer_key_enrollment) do
    [
      "Attach operator-supplied peer/key enrollment evidence and show passive BLE observations are rejected as enrollment."
    ]
  end

  defp notes(:authorship_fixture_matrix) do
    [
      "Attach full-envelope authorship positive and tamper/key-mismatch negative fixtures."
    ]
  end

  defp notes(:replay_state_lifecycle) do
    [
      "Attach duplicate rejection, pruning, restart clearing, expiry, and beacon-ref replay rejection evidence."
    ]
  end

  defp notes(:trust_policy_lifecycle) do
    [
      "Attach supplied-policy trust, blocked, revoked, rotation, and persistence-lifecycle decision evidence."
    ]
  end

  defp notes(:canonical_replay_integration) do
    [
      "Attach canonical ReceivedMessage replay decisions that require supplied proof, binding, replay state, and explicit trust."
    ]
  end

  defp notes(:beacon_ref_authentication_integration) do
    [
      "Attach evidence that beacon refs authenticate only after matching a resolved trusted full envelope."
    ]
  end

  defp notes(:release_artifact_evidence) do
    [
      "Attach readiness, release, security manifest, and release-note wording evidence that keeps trusted delivery blocked."
    ]
  end

  defp notes(:negative_claim_review) do
    [
      "Attach implementation-backed negative fixtures for tamper, replay, key mismatch, blocked/revoked trust, and hash-only beacon promotion."
    ]
  end

  defp review_commands do
    [
      "mix mob.node.local_security.release_review --template --out artifacts/local-ble/<run-id>/security/evidence.json",
      "mix mob.node.local_security.release_review --input artifacts/local-ble/<run-id>/security/evidence.json --json --out tmp/local-security-release-review.json"
    ]
  end
end
