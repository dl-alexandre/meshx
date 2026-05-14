defmodule MeshxMobileApp.BLE.LocalSecurityPeerEnrollmentTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.{
    LocalSecurityAuthorshipProof,
    LocalSecurityPeerEnrollment,
    LocalSecurityPeerIdentityBinding,
    MessageEnvelope
  }

  test "enrolls operator-supplied peer key material as untrusted identity evidence" do
    {public_key, _private_key} = :crypto.generate_key(:eddsa, :ed25519)

    assert {:ok, enrollment} =
             LocalSecurityPeerEnrollment.enroll("meshx-alpha", public_key,
               enrolled_at: 1_700,
               label: "Alice phone"
             )

    assert enrollment.enrollment_version == 1
    assert enrollment.source == :operator_supplied_ed25519_key
    assert enrollment.peer_id == "meshx-alpha"
    assert enrollment.key_id == LocalSecurityAuthorshipProof.derive_key_id(public_key)
    assert enrollment.public_key == public_key
    assert enrollment.label == "Alice phone"
    assert enrollment.enrolled_at == 1_700
    assert enrollment.trust_state == :untrusted
    assert :trusted_message in enrollment.blocked_claims
  end

  test "enrollment can be converted into a peer identity binding for authorship checks" do
    {public_key, private_key} = :crypto.generate_key(:eddsa, :ed25519)
    envelope = envelope()

    assert {:ok, enrollment} =
             LocalSecurityPeerEnrollment.enroll("meshx-alpha", public_key, enrolled_at: 1_700)

    assert {:ok, binding} = LocalSecurityPeerEnrollment.to_binding(enrollment)
    assert binding.peer_id == enrollment.peer_id
    assert binding.key_id == enrollment.key_id

    assert {:ok, proof} = LocalSecurityAuthorshipProof.sign(envelope, private_key, binding.key_id)
    assert {:ok, result} = LocalSecurityPeerIdentityBinding.verify(envelope, proof, binding)

    assert result.authenticated_peer_identity?
    assert result.authorship_proof?
  end

  test "passive BLE observations cannot enroll peer identity" do
    observation = %{
      advertised_name: "meshx-alpha",
      received_device_id: "AA:BB:CC:DD:EE:01",
      message_id_hash: <<1::64>>,
      sender_peer_hash: <<2::64>>
    }

    assert {:error, :passive_observation_not_enrollment} =
             LocalSecurityPeerEnrollment.reject_passive_observation(observation)
  end

  test "rejects missing or malformed enrollment inputs" do
    {public_key, _private_key} = :crypto.generate_key(:eddsa, :ed25519)

    assert {:error, :missing_enrolled_at} =
             LocalSecurityPeerEnrollment.enroll("meshx-alpha", public_key)

    assert {:error, :invalid_enrolled_at} =
             LocalSecurityPeerEnrollment.enroll("meshx-alpha", public_key, enrolled_at: -1)

    assert {:error, :invalid_label} =
             LocalSecurityPeerEnrollment.enroll("meshx-alpha", public_key,
               enrolled_at: 1,
               label: String.duplicate("x", 65)
             )

    assert {:error, :invalid_public_key} =
             LocalSecurityPeerEnrollment.enroll("meshx-alpha", <<1, 2>>, enrolled_at: 1)
  end

  test "JSON snapshot keeps trust and delivery claims blocked" do
    snapshot = LocalSecurityPeerEnrollment.json_snapshot()

    assert snapshot["boundary"] == "operator_supplied_peer_key_enrollment"
    assert snapshot["passive_observation_enrollment_allowed?"] == false
    assert snapshot["trusted_peer_identity_claim_allowed?"] == false
    assert snapshot["trusted_message_claim_allowed?"] == false
    assert snapshot["trusted_delivery_claim_allowed?"] == false
    assert "trusted_delivery" in snapshot["blocked_claims"]
  end

  defp envelope do
    assert {:ok, envelope} =
             MessageEnvelope.build(
               message_id: "message-id-00001",
               sender_peer_id: "meshx-alpha",
               recipient_peer_id: nil,
               created_at: 1_700_000_000_000,
               ttl: 4,
               payload_type: "text",
               payload: "hello",
               capability_requirements: 0
             )

    envelope
  end
end
