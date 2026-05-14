defmodule MeshxMobileApp.BLE.LocalSecurityBeaconReferenceRiskTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.{BeaconRef, LocalSecurityBeaconReferenceRisk}

  test "classifies a valid beacon ref as a pointer only" do
    ref = beacon_ref()

    risk = LocalSecurityBeaconReferenceRisk.classify(ref)

    assert risk.status == :valid_pointer
    assert risk.valid_beacon_ref?
    assert risk.hash_reference_only?
    refute risk.authenticated_peer_identity?
    refute risk.authenticated_message?
    refute risk.trusted_message?
    refute risk.trusted_delivery_claim_allowed?
    refute risk.freshness_claim_allowed?
    assert risk.message_id_hash == ref.message_id_hash
    assert :authenticated_peer_identity in risk.blocked_claims
    assert :message_authorship_proof in risk.required_before_trust
  end

  test "rejects malformed refs before trust classification" do
    invalid = %{beacon_ref() | sender_peer_hash: <<1, 2, 3>>}

    risk = LocalSecurityBeaconReferenceRisk.classify(invalid)

    assert risk.status == :invalid_reference
    refute risk.valid_beacon_ref?
    refute risk.hash_reference_only?
    assert risk.reasons == [:invalid_sender_peer_hash]
    assert :valid_beacon_ref in risk.blocked_claims
    refute risk.trusted_delivery_claim_allowed?
  end

  test "rejects non beacon refs" do
    risk = LocalSecurityBeaconReferenceRisk.classify(%{})

    assert risk.status == :invalid_reference
    assert risk.reasons == [:invalid_beacon_ref]
    refute risk.trusted_message?
  end

  test "snapshot documents hash-only trust boundary" do
    snapshot = LocalSecurityBeaconReferenceRisk.snapshot()

    assert snapshot.boundary == :hash_only_beacon_reference_security_risk
    assert snapshot.valid_beacon_ref_claim_allowed?
    refute snapshot.authenticated_peer_identity_claim_allowed?
    refute snapshot.authenticated_message_claim_allowed?
    refute snapshot.trusted_message_claim_allowed?
    refute snapshot.trusted_delivery_claim_allowed?
    refute snapshot.freshness_claim_allowed?
    assert :resolved_full_envelope in snapshot.required_before_trust
    assert :authenticated_message in snapshot.blocked_claims
  end

  defp beacon_ref do
    {:ok, ref} =
      BeaconRef.new(
        envelope_version: 1,
        payload_kind: "TX",
        message_id_hash: <<1, 2, 3, 4, 5, 6, 7, 8>>,
        sender_peer_hash: <<8, 7, 6, 5, 4, 3, 2, 1>>,
        observed_at: 1_700_000_000_000,
        received_device_id: "AA:BB",
        rssi: -61
      )

    ref
  end
end
