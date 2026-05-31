defmodule Mob.Node.BLE.LocalSecurityEvidenceManifest do
  @moduledoc """
  Machine-readable local security evidence manifest.

  The manifest packages current security boundaries, fixture coverage,
  lifecycle policies, and release evidence review requirements. It is an
  artifact shape only. It does not persist keys, persist trust, persist replay
  state, fetch envelopes, inspect hardware, route, ACK, retry, encrypt, or run
  background work.
  """

  alias Mob.Node.BLE.{
    LocalSecurityAcceptance,
    LocalSecurityBeaconReferenceRisk,
    LocalSecurityDecisionScenarioPlan,
    LocalSecurityFixtureAudit,
    LocalSecurityIdentityValidationPlan,
    LocalSecurityOperatorCapturePlan,
    LocalSecurityReleaseEvidenceReview,
    LocalSecurityReplayLifecyclePolicy,
    LocalSecurityReplayLifecycleValidation,
    LocalSecurityTrustLifecycleValidation,
    LocalTrustPolicy
  }

  @required_commands [
    "mix mob.node.local_security.validation_plan --json --out <path>",
    "mix mob.node.local_security.evidence --json --out <path>",
    "mix mob.node.local_security.release_review --template --out <path>",
    "mix mob.node.local_security.release_review --input <path> --json --out <path>",
    "mix test apps/mob_node/test/mob_node/ble/local_security_authorship_proof_test.exs",
    "mix test apps/mob_node/test/mob_node/ble/local_security_canonical_replay_decision_test.exs",
    "mix test apps/mob_node/test/mob_node/ble/local_security_decision_scenario_plan_test.exs",
    "mix test apps/mob_node/test/mob_node/ble/local_security_fixture_audit_test.exs",
    "mix test apps/mob_node/test/mob_node/ble/local_security_operator_capture_plan_test.exs",
    "mix test apps/mob_node/test/mob_node/ble/local_security_replay_lifecycle_validation_test.exs",
    "mix test apps/mob_node/test/mob_node/ble/local_security_trust_lifecycle_validation_test.exs",
    "mix test apps/mob_node/test/mob_node/ble/local_security_release_evidence_review_test.exs",
    "mix test apps/mob_node/test/mob_node/ble/local_security_beacon_reference_risk_test.exs",
    "mix test apps/mob_node/test/mob_node/ble/local_security_crypto_negative_validation_test.exs"
  ]

  @spec snapshot() :: map()
  def snapshot do
    validation_plan = LocalSecurityIdentityValidationPlan.snapshot()
    fixture_audit = LocalSecurityFixtureAudit.snapshot()
    release_review = LocalSecurityReleaseEvidenceReview.review(review_input())

    %{
      manifest_version: 1,
      boundary: :local_security_evidence_manifest,
      security_evidence_complete?: false,
      authenticated_peer_identity_claim_allowed?: false,
      authenticated_message_claim_allowed?: false,
      trusted_message_claim_allowed?: false,
      trusted_delivery_claim_allowed?: false,
      security_scope: security_scope(),
      current_security_decision: LocalTrustPolicy.current_decision(),
      security_decision_scenario_plan: LocalSecurityDecisionScenarioPlan.snapshot(),
      validation_plan: validation_plan,
      fixture_audit: fixture_audit,
      acceptance: LocalSecurityAcceptance.snapshot(%{trust_evidence: []}),
      replay_lifecycle_policy: LocalSecurityReplayLifecyclePolicy.snapshot(),
      replay_lifecycle_validation: LocalSecurityReplayLifecycleValidation.snapshot(),
      trust_lifecycle_validation: LocalSecurityTrustLifecycleValidation.snapshot(),
      beacon_reference_risk: LocalSecurityBeaconReferenceRisk.snapshot(),
      operator_capture_plan: LocalSecurityOperatorCapturePlan.snapshot(),
      release_evidence_review: release_review,
      required_commands: @required_commands,
      required_artifacts: required_artifacts(),
      blocked_claims: blocked_claims(),
      open_security_gate_count: validation_plan.blocked_gate_count,
      partial_fixture_group_count: fixture_audit.partial_count,
      blocked_fixture_group_count: fixture_audit.blocked_count,
      missing_release_evidence: release_review.missing,
      notes: [
        "This manifest packages current local security evidence without enabling trusted claims.",
        "Security release evidence can be ready for review while underlying security gates remain open.",
        "Current BLE inbox observations are unsigned local observations, not trusted messages.",
        "Beacon authentication still depends on full-envelope resolution evidence."
      ]
    }
  end

  @spec json_snapshot() :: map()
  def json_snapshot do
    snapshot()
    |> JSON.encode!()
    |> JSON.decode!()
  end

  defp required_artifacts do
    [
      %{
        id: :security_validation_plan,
        command: "mix mob.node.local_security.validation_plan --json --out <path>",
        purpose:
          "Archive the authenticated local BLE security validation checklist before release evidence review."
      },
      %{
        id: :security_manifest,
        command: "mix mob.node.local_security.evidence --json --out <path>",
        purpose: "Archive current local security evidence, gaps, and blocked claims."
      },
      %{
        id: :current_security_decision,
        source: "LocalTrustPolicy.current_decision",
        purpose:
          "Archive the keep_unsigned_local_observation decision_outcome for the current validated advertisement-only mode before any trusted-message wording changes."
      },
      %{
        id: :security_decision_scenario_plan,
        source: "LocalSecurityDecisionScenarioPlan",
        purpose:
          "Archive keep_unsigned_local_observation and enable_authenticated_local_trust decision scenarios, including required security gates and blocked trusted claims."
      },
      %{
        id: :security_release_review_template,
        command: "mix mob.node.local_security.release_review --template --out <path>",
        purpose:
          "Generate incomplete operator metadata scaffold for local security release evidence."
      },
      %{
        id: :security_operator_capture_plan,
        source: "LocalSecurityOperatorCapturePlan",
        purpose:
          "Archive the security operator capture checklist for peer/key enrollment, authorship, replay lifecycle, trust lifecycle, canonical replay, beacon authentication, release evidence, and negative claim review."
      },
      %{
        id: :security_release_review,
        command: "mix mob.node.local_security.release_review --input <path> --json --out <path>",
        purpose: "Verify operator-reviewed security evidence package metadata."
      },
      %{
        id: :security_fixture_audit,
        source: "LocalSecurityFixtureAudit",
        purpose: "Inventory implementation-backed fixture coverage for every security gate."
      },
      %{
        id: :beacon_reference_risk,
        source: "LocalSecurityBeaconReferenceRisk",
        purpose:
          "Prove hash-only legacy beacon refs are compact pointers, not authenticated identity, authorship, freshness, trust, or delivery evidence."
      },
      %{
        id: :security_negative_validation,
        source: "LocalSecurityCryptoNegativeValidation",
        purpose:
          "Prove tamper, replay, key mismatch, non-matching trusted policy, blocked/revoked, and hash-only cases fail closed."
      }
    ]
  end

  defp security_scope do
    %{
      current_mode: :unsigned_local_ble_observations,
      scope_status: :partial_security_boundary,
      implemented_boundaries: [
        :canonical_replay_ingress,
        :local_trust_policy_decision,
        :beacon_reference_risk_inventory,
        :memory_only_replay_lifecycle_policy,
        :trust_lifecycle_validation,
        :crypto_negative_validation_fixture_inventory
      ],
      blocked_claims: blocked_claims(),
      requires_before_trusted_message: [
        :authenticated_peer_identity,
        :message_authorship_proof,
        :peer_binding,
        :replay_protection,
        :trust_lifecycle_evidence,
        :full_envelope_resolution_for_beacon_refs,
        :operator_reviewed_security_release_evidence
      ],
      not_evidence_of: [
        :trusted_message,
        :trusted_delivery,
        :authenticated_ble_hardware,
        :durable_trust_store,
        :durable_replay_protection,
        :beacon_ref_authorship,
        :fresh_message
      ],
      notes: [
        "Hash-only beacon refs are compact references, not authorship, identity, freshness, or trust proof.",
        "Pure fixture and lifecycle boundaries document fail-closed behavior but do not authenticate hardware observations.",
        "Trusted-message wording stays blocked until authenticated identity, authorship, replay, and trust lifecycle gates pass."
      ]
    }
  end

  defp review_input do
    %{
      readiness_manifest_path: "tmp/local-readiness.json",
      release_manifest_path: "tmp/local-release.json",
      security_manifest_path: "tmp/local-security-evidence.json",
      security_attachments: [
        %{
          artifact_id: "local-security-evidence",
          path: "tmp/local-security-evidence.json",
          source: "LocalSecurityEvidenceManifest",
          plan_gate_ids: LocalSecurityReleaseEvidenceReview.required_plan_gate_ids(),
          blocked_claims_called_out: LocalSecurityReleaseEvidenceReview.required_blocked_claims(),
          operator_reviewed?: false
        }
      ]
    }
  end

  defp blocked_claims do
    [
      :authenticated_peer_identity,
      :authenticated_message,
      :trusted_message,
      :trusted_delivery,
      :fresh_message,
      :guaranteed_delivery,
      :routed_delivery
    ]
  end
end
