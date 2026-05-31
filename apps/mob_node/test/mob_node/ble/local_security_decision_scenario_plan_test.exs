defmodule Mob.Node.BLE.LocalSecurityDecisionScenarioPlanTest do
  use ExUnit.Case, async: true

  alias Mob.Node.BLE.LocalSecurityDecisionScenarioPlan

  test "snapshot exposes security decision scenarios without trusted claims" do
    plan = LocalSecurityDecisionScenarioPlan.snapshot()

    assert plan.boundary == :local_security_decision_scenario_plan
    assert plan.status == :open
    assert plan.selected_decision_outcome == :keep_unsigned_local_observation
    refute plan.authenticated_peer_identity_claim_allowed?
    refute plan.authenticated_message_claim_allowed?
    refute plan.trusted_message_claim_allowed?
    refute plan.trusted_delivery_claim_allowed?
    refute plan.fresh_message_claim_allowed?
  end

  test "decision scenarios cover unsigned and authenticated trust outcomes" do
    plan = LocalSecurityDecisionScenarioPlan.snapshot()
    outcomes = Enum.map(plan.decision_scenarios, & &1.decision_outcome)

    assert [:keep_unsigned_local_observation, :enable_authenticated_local_trust] -- outcomes == []

    assert plan.allowed_decision_outcomes == [
             :keep_unsigned_local_observation,
             :enable_authenticated_local_trust
           ]

    unsigned = Enum.find(plan.decision_scenarios, &(&1.id == :keep_unsigned_local_observation))
    trusted = Enum.find(plan.decision_scenarios, &(&1.id == :enable_authenticated_local_trust))

    assert unsigned.status == :selected_for_current_validated_mode
    assert unsigned.security_mode_after_decision == :unsigned_local_ble_observations
    refute unsigned.authenticated_peer_identity_enabled?
    refute unsigned.authenticated_message_enabled?
    refute unsigned.trusted_message_enabled?

    assert trusted.status == :blocked
    assert trusted.security_mode_after_decision == :authenticated_local_trusted_message
    refute trusted.authenticated_peer_identity_enabled?
    refute trusted.authenticated_message_enabled?
    refute trusted.trusted_message_enabled?
  end

  test "authenticated trust scenario names every security validation gate" do
    plan = LocalSecurityDecisionScenarioPlan.snapshot()
    trusted = Enum.find(plan.decision_scenarios, &(&1.id == :enable_authenticated_local_trust))

    assert [
             :peer_key_enrollment,
             :authorship_fixture_matrix,
             :replay_state_lifecycle,
             :trust_policy_lifecycle,
             :canonical_replay_integration,
             :beacon_ref_authentication_integration,
             :release_artifact_evidence,
             :negative_claim_review
           ] -- trusted.required_gates == []

    assert trusted.missing_evidence != []
    assert :authenticated_peer_identity in trusted.blocked_claims_called_out
    assert :trusted_message in trusted.blocked_claims_called_out
    assert :trusted_delivery in trusted.blocked_claims_called_out
  end

  test "unsigned scenario preserves release wording blockers" do
    plan = LocalSecurityDecisionScenarioPlan.snapshot()
    unsigned = Enum.find(plan.decision_scenarios, &(&1.id == :keep_unsigned_local_observation))

    assert Enum.any?(
             unsigned.required_operator_evidence,
             &String.contains?(&1, "unsigned local observation wording")
           )

    assert :authenticated_message in unsigned.blocked_claims_called_out
    assert :trusted_message in unsigned.blocked_claims_called_out
    assert :trusted_delivery in unsigned.blocked_claims_called_out
  end

  test "JSON snapshot is archiveable" do
    plan = LocalSecurityDecisionScenarioPlan.json_snapshot()

    assert plan["boundary"] == "local_security_decision_scenario_plan"
    assert plan["selected_decision_outcome"] == "keep_unsigned_local_observation"
    assert length(plan["decision_scenarios"]) == 2
    assert plan["trusted_message_claim_allowed?"] == false
    assert plan["trusted_delivery_claim_allowed?"] == false
  end
end
