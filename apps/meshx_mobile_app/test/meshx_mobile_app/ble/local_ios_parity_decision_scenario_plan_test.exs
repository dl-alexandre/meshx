defmodule MeshxMobileApp.BLE.LocalIOSParityDecisionScenarioPlanTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.LocalIOSParityDecisionScenarioPlan

  test "snapshot exposes iOS parity decision scenarios without enabling iOS claims" do
    plan = LocalIOSParityDecisionScenarioPlan.snapshot()

    assert plan.boundary == :local_ios_parity_decision_scenario_plan
    assert plan.status == :open
    assert plan.selected_decision_outcome == :keep_ios_contract_only
    refute plan.ios_participation_claim_allowed?
    refute plan.ios_hardware_claim_allowed?
    refute plan.ios_legacy_beacon_observe_claim_allowed?
    refute plan.ios_legacy_beacon_gossip_claim_allowed?
    refute plan.ios_full_envelope_advert_claim_allowed?
    refute plan.ios_background_ble_claim_allowed?
    refute plan.ios_parity_claim_allowed?
  end

  test "decision scenarios cover contract-only and advert-only participation outcomes" do
    plan = LocalIOSParityDecisionScenarioPlan.snapshot()
    outcomes = Enum.map(plan.decision_scenarios, & &1.decision_outcome)

    assert [:keep_ios_contract_only, :enable_ios_advert_only_participation] -- outcomes == []

    assert plan.allowed_decision_outcomes == [
             :keep_ios_contract_only,
             :enable_ios_advert_only_participation
           ]

    contract = Enum.find(plan.decision_scenarios, &(&1.id == :keep_ios_contract_only))

    participation =
      Enum.find(
        plan.decision_scenarios,
        &(&1.id == :enable_ios_advert_only_participation)
      )

    assert contract.status == :selected_for_current_validated_mode
    assert contract.ios_mode_after_decision == :contract_only
    refute contract.ios_hardware_participation_enabled?
    refute contract.ios_legacy_beacon_observe_claim_allowed?
    refute contract.ios_legacy_beacon_gossip_claim_allowed?
    refute contract.ios_full_envelope_advert_claim_allowed?
    refute contract.ios_background_ble_claim_allowed?

    assert participation.status == :blocked
    assert participation.ios_mode_after_decision == :ios_advert_only_participation
    refute participation.ios_hardware_participation_enabled?
    refute participation.ios_legacy_beacon_observe_claim_allowed?
    refute participation.ios_legacy_beacon_gossip_claim_allowed?
    refute participation.ios_full_envelope_advert_claim_allowed?
    refute participation.ios_background_ble_claim_allowed?
  end

  test "iOS participation scenario names every iOS validation gate" do
    plan = LocalIOSParityDecisionScenarioPlan.snapshot()

    participation =
      Enum.find(
        plan.decision_scenarios,
        &(&1.id == :enable_ios_advert_only_participation)
      )

    assert [
             :target_ios_device_matrix,
             :canonical_ingress_fixture,
             :legacy_beacon_observe_hardware,
             :legacy_beacon_gossip_hardware,
             :full_envelope_capability_probe,
             :hardware_replay_fixture,
             :ios_background_ble_boundary,
             :negative_claim_review
           ] -- participation.required_gates == []

    assert participation.missing_evidence != []
    assert :ios_hardware_participation in participation.blocked_claims_called_out
    assert :ios_legacy_beacon_observed in participation.blocked_claims_called_out
    assert :ios_legacy_beacon_gossip in participation.blocked_claims_called_out
    assert :ios_full_envelope_advert in participation.blocked_claims_called_out
    assert :ios_parity_claim in participation.blocked_claims_called_out
  end

  test "contract-only scenario preserves release wording blockers" do
    plan = LocalIOSParityDecisionScenarioPlan.snapshot()
    contract = Enum.find(plan.decision_scenarios, &(&1.id == :keep_ios_contract_only))

    assert Enum.any?(
             contract.required_operator_evidence,
             &String.contains?(&1, "iOS contract-only wording")
           )

    assert :ios_hardware_participation in contract.blocked_claims_called_out
    assert :ios_legacy_beacon_gossip in contract.blocked_claims_called_out
    assert :ios_hardware_replay_fixture in contract.blocked_claims_called_out
    assert :ios_parity_claim in contract.blocked_claims_called_out
  end

  test "JSON snapshot is archiveable" do
    plan = LocalIOSParityDecisionScenarioPlan.json_snapshot()

    assert plan["boundary"] == "local_ios_parity_decision_scenario_plan"
    assert plan["selected_decision_outcome"] == "keep_ios_contract_only"
    assert length(plan["decision_scenarios"]) == 2
    assert plan["ios_participation_claim_allowed?"] == false
    assert plan["ios_hardware_claim_allowed?"] == false
    assert plan["ios_parity_claim_allowed?"] == false
  end
end
