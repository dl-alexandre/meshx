defmodule Mob.Node.BLE.LocalSecurityFixtureAuditTest do
  use ExUnit.Case, async: true

  alias Mob.Node.BLE.{
    LocalSecurityCryptoNegativeValidation,
    LocalSecurityFixtureAudit
  }

  test "snapshot inventories fixture coverage for every security validation plan gate" do
    snapshot = LocalSecurityFixtureAudit.snapshot()

    assert snapshot.boundary == :local_security_fixture_inventory
    assert snapshot.current_mode == :pure_security_boundaries_only
    assert snapshot.fixture_count == 8
    assert snapshot.plan_gate_count == 8
    assert snapshot.represented_plan_gate_count == 8
    assert snapshot.missing_plan_gate_ids == []
    assert snapshot.all_validation_plan_gates_represented?

    assert snapshot.covered_current_boundary_count == 2
    assert snapshot.partial_count == 5
    assert snapshot.blocked_count == 1

    refute snapshot.authenticated_peer_identity_claim_allowed?
    refute snapshot.authenticated_message_claim_allowed?
    refute snapshot.trusted_message_claim_allowed?
    refute snapshot.trusted_delivery_claim_allowed?
    refute snapshot.replay_protection_claim_allowed?
  end

  test "canonical replay and negative fixtures are represented without trusted delivery claims" do
    snapshot = LocalSecurityFixtureAudit.snapshot()

    canonical = fixture(snapshot, :canonical_replay_security_matrix)
    assert canonical.plan_gate_id == :canonical_replay_integration
    assert canonical.status == :covered_current_boundary
    assert :trusted_delivery in canonical.blocked_claims

    negative = fixture(snapshot, :crypto_negative_claim_matrix)
    assert negative.plan_gate_id == :negative_claim_review
    assert negative.status == :covered_current_boundary

    for case_id <- LocalSecurityCryptoNegativeValidation.required_case_ids() do
      assert Enum.any?(negative.evidence, &String.contains?(&1, Atom.to_string(case_id)))
    end

    refute Enum.any?(
             negative.missing_evidence,
             &String.contains?(&1, "passive labels, stale refs")
           )
  end

  test "partial and blocked fixture groups preserve missing security work" do
    snapshot = LocalSecurityFixtureAudit.snapshot()

    authorship = fixture(snapshot, :authorship_proof_matrix)
    assert authorship.status == :partial

    assert Enum.any?(
             authorship.evidence,
             &String.contains?(&1, "message_id, sender_peer_id, recipient_peer_id")
           )

    assert Enum.any?(
             authorship.evidence,
             &String.contains?(
               &1,
               "message_id, sender_peer_id, payload_kind, payload bytes, envelope_version"
             )
           )

    refute Enum.any?(
             authorship.missing_evidence,
             &String.contains?(&1, "Expanded canonical replay mutations")
           )

    enrollment = fixture(snapshot, :supplied_peer_key_binding)
    assert enrollment.status == :partial
    assert Enum.any?(enrollment.missing_evidence, &String.contains?(&1, "enrollment flow"))

    beacon = fixture(snapshot, :beacon_pointer_authentication_matrix)
    assert beacon.status == :partial
    assert Enum.any?(beacon.missing_evidence, &String.contains?(&1, "resolution transport"))

    release = fixture(snapshot, :security_release_artifact_review)
    assert release.status == :blocked
    assert Enum.any?(release.missing_evidence, &String.contains?(&1, "Release-candidate"))
  end

  test "JSON snapshot preserves fixture and blocked claim data" do
    snapshot = LocalSecurityFixtureAudit.json_snapshot()

    assert snapshot["boundary"] == "local_security_fixture_inventory"
    assert snapshot["trusted_message_claim_allowed?"] == false
    assert snapshot["trusted_delivery_claim_allowed?"] == false
    assert "trusted_delivery" in snapshot["blocked_claims"]

    assert Enum.any?(
             snapshot["fixtures"],
             &(&1["id"] == "canonical_replay_security_matrix" and
                 &1["status"] == "covered_current_boundary")
           )
  end

  defp fixture(snapshot, id), do: Enum.find(snapshot.fixtures, &(&1.id == id))
end
