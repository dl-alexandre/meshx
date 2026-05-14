defmodule MeshxMobileApp.BLE.LocalSecurityBeaconAuthenticationTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.{
    BeaconRef,
    LocalSecurityBeaconAuthentication,
    MessageEnvelope
  }

  test "authenticates a beacon ref only after matching a trusted full envelope" do
    envelope = envelope()
    ref = beacon_ref(envelope)
    decision = %{trusted_message?: true}

    assert {:ok, evidence} =
             LocalSecurityBeaconAuthentication.authenticate(ref, envelope, decision)

    assert evidence.authenticated_beacon_ref?
    assert evidence.authenticated_message_ref?
    assert evidence.trusted_message?
    refute evidence.trusted_delivery_claim_allowed?
    assert evidence.message_id_hash == BeaconRef.message_id_hash(envelope)
    assert evidence.sender_peer_hash == BeaconRef.sender_peer_hash(envelope)
    assert :trusted_delivery in evidence.blocked_claims
  end

  test "rejects hash mismatch even when the envelope decision is trusted" do
    envelope = envelope()
    mismatched = %{beacon_ref(envelope) | sender_peer_hash: <<255::64>>}

    assert {:error, :beacon_ref_mismatch, evidence} =
             LocalSecurityBeaconAuthentication.authenticate(mismatched, envelope, %{
               trusted_message?: true
             })

    refute evidence.authenticated_beacon_ref?
    assert :beacon_ref_mismatch in evidence.reasons
  end

  test "rejects matching beacon ref when the resolved envelope is not trusted" do
    envelope = envelope()
    ref = beacon_ref(envelope)

    assert {:error, :untrusted_envelope, evidence} =
             LocalSecurityBeaconAuthentication.authenticate(ref, envelope, %{
               trusted_message?: false
             })

    refute evidence.authenticated_beacon_ref?
    assert :trusted_message in evidence.blocked_claims
  end

  test "rejects malformed beacon refs and non-envelope inputs" do
    envelope = envelope()

    assert {:error, :invalid_beacon_ref, evidence} =
             LocalSecurityBeaconAuthentication.authenticate(
               %{message_id_hash: <<1::64>>, sender_peer_hash: <<2::64>>},
               envelope,
               %{trusted_message?: true}
             )

    refute evidence.authenticated_beacon_ref?

    assert {:error, :invalid_beacon_ref, _evidence} =
             LocalSecurityBeaconAuthentication.authenticate(
               beacon_ref(envelope),
               %{message_id: envelope.message_id},
               %{trusted_message?: true}
             )
  end

  test "beacon authentication remains pointer authentication, not delivery" do
    envelope = envelope()
    ref = beacon_ref(envelope)

    assert {:ok, evidence} =
             LocalSecurityBeaconAuthentication.authenticate(ref, envelope, %{
               trusted_message?: true
             })

    refute evidence.trusted_delivery_claim_allowed?
    assert "This is pointer authentication, not delivery." in evidence.notes
  end

  defp beacon_ref(envelope) do
    assert {:ok, ref} =
             BeaconRef.new(
               envelope_version: envelope.envelope_version,
               payload_kind: envelope.payload_type,
               message_id_hash: BeaconRef.message_id_hash(envelope),
               sender_peer_hash: BeaconRef.sender_peer_hash(envelope),
               observed_at: 1_200,
               received_device_id: "device-a",
               rssi: -70
             )

    ref
  end

  defp envelope do
    assert {:ok, envelope} =
             MessageEnvelope.build(
               message_id: "message-id-00001",
               sender_peer_id: "meshx-alpha",
               recipient_peer_id: nil,
               created_at: 1_000,
               ttl: 4,
               payload_type: "text",
               payload: "hello",
               capability_requirements: 0
             )

    envelope
  end
end
