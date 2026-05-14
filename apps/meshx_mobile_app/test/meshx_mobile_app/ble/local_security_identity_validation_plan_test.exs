defmodule MeshxMobileApp.BLE.LocalSecurityIdentityValidationPlanTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.LocalSecurityIdentityValidationPlan

  test "snapshot records blocked authenticated security validation gates" do
    snapshot = LocalSecurityIdentityValidationPlan.snapshot()

    assert snapshot.boundary == :authenticated_local_ble_security_validation_plan
    assert snapshot.current_mode == :unsigned_local_ble_observations
    refute snapshot.authenticated_peer_identity_claim_allowed?
    refute snapshot.authenticated_message_claim_allowed?
    refute snapshot.trusted_message_claim_allowed?
    refute snapshot.trusted_delivery_claim_allowed?
    refute snapshot.replay_protection_claim_allowed?
    assert snapshot.gate_count == 8
    assert snapshot.blocked_gate_count == 8

    assert [
             %{id: :peer_key_enrollment, status: :blocked},
             %{id: :authorship_fixture_matrix, status: :blocked},
             %{id: :replay_state_lifecycle, status: :blocked},
             %{id: :trust_policy_lifecycle, status: :blocked},
             %{id: :canonical_replay_integration, status: :blocked},
             %{id: :beacon_ref_authentication_integration, status: :blocked},
             %{id: :release_artifact_evidence, status: :blocked},
             %{id: :negative_claim_review, status: :blocked}
           ] = snapshot.gates
  end

  test "security gates require enrollment authorship replay trust beacon and negative evidence" do
    snapshot = LocalSecurityIdentityValidationPlan.snapshot()

    assert gate(snapshot, :peer_key_enrollment).missing_evidence
           |> Enum.any?(&String.contains?(&1, "key enrollment"))

    assert gate(snapshot, :authorship_fixture_matrix).missing_evidence
           |> Enum.any?(&String.contains?(&1, "Release evidence"))

    assert gate(snapshot, :replay_state_lifecycle).missing_evidence
           |> Enum.any?(&String.contains?(&1, "Durable replay-state"))

    assert gate(snapshot, :beacon_ref_authentication_integration).missing_evidence
           |> Enum.any?(&String.contains?(&1, "resolution transport"))

    assert gate(snapshot, :negative_claim_review).missing_evidence
           |> Enum.any?(&String.contains?(&1, "crypto negative"))
  end

  test "canonical replay gate records implemented fixture coverage while blocking delivery claims" do
    gate = LocalSecurityIdentityValidationPlan.snapshot() |> gate(:canonical_replay_integration)

    refute Enum.any?(gate.missing_evidence, &String.contains?(&1, "Positive canonical replay"))

    assert Enum.any?(
             gate.notes,
             &String.contains?(&1, "LocalSecurityCanonicalReplayDecisionTest covers positive")
           )

    assert Enum.any?(
             gate.missing_evidence,
             &String.contains?(&1, "operator-reviewed security wording")
           )

    assert :trusted_delivery in gate.blocked_claims
  end

  test "authorship gate records implemented positive fixture coverage while blocking trust claims" do
    gate = LocalSecurityIdentityValidationPlan.snapshot() |> gate(:authorship_fixture_matrix)

    refute Enum.any?(
             gate.missing_evidence,
             &String.contains?(&1, "Implementation-backed positive authorship")
           )

    assert Enum.any?(
             gate.notes,
             &String.contains?(
               &1,
               "message_id, sender_peer_id, payload_kind, payload, envelope_version"
             )
           )

    assert Enum.any?(
             gate.missing_evidence,
             &String.contains?(&1, "operator-reviewed security wording")
           )

    assert :trusted_message in gate.blocked_claims
  end

  test "replay lifecycle gate records memory-only validation while blocking durable freshness claims" do
    gate = LocalSecurityIdentityValidationPlan.snapshot() |> gate(:replay_state_lifecycle)

    refute Enum.any?(
             gate.missing_evidence,
             &String.contains?(&1, "Implementation-backed fixtures for duplicate")
           )

    assert Enum.any?(
             gate.notes,
             &String.contains?(&1, "LocalSecurityReplayLifecycleValidation proves")
           )

    assert Enum.any?(
             gate.missing_evidence,
             &String.contains?(&1, "Durable replay-state product decision")
           )

    assert :fresh_message in gate.blocked_claims
  end

  test "trust lifecycle gate records supplied-policy validation while blocking persistent trust claims" do
    gate = LocalSecurityIdentityValidationPlan.snapshot() |> gate(:trust_policy_lifecycle)

    refute Enum.any?(
             gate.missing_evidence,
             &String.contains?(&1, "Positive and negative fixtures")
           )

    assert Enum.any?(
             gate.notes,
             &String.contains?(&1, "LocalSecurityTrustLifecycleValidation covers")
           )

    assert Enum.any?(
             gate.missing_evidence,
             &String.contains?(&1, "Durable trust lifecycle implementation")
           )

    assert :trusted_message in gate.blocked_claims
  end

  test "JSON snapshot preserves blocked trusted claims" do
    snapshot = LocalSecurityIdentityValidationPlan.json_snapshot()

    assert snapshot["boundary"] == "authenticated_local_ble_security_validation_plan"
    assert snapshot["trusted_message_claim_allowed?"] == false
    assert snapshot["trusted_delivery_claim_allowed?"] == false

    assert Enum.any?(
             snapshot["gates"],
             &(&1["id"] == "canonical_replay_integration" and &1["status"] == "blocked")
           )
  end

  defp gate(snapshot, id), do: Enum.find(snapshot.gates, &(&1.id == id))
end
