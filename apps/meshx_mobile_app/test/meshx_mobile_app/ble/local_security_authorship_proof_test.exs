defmodule MeshxMobileApp.BLE.LocalSecurityAuthorshipProofTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.{LocalSecurityAuthorshipProof, MessageEnvelope}
  alias MeshxMobileApp.BLE.LocalSecurityAuthorshipProof.Proof

  test "signing payload is deterministic and domain separated" do
    envelope = envelope()

    assert {:ok, payload} = LocalSecurityAuthorshipProof.signing_payload(envelope)

    assert payload ==
             LocalSecurityAuthorshipProof.domain_separator() <> MessageEnvelope.encode(envelope)
  end

  test "signs and verifies a full envelope with supplied Ed25519 key material" do
    {public_key, private_key} = :crypto.generate_key(:eddsa, :ed25519)
    key_id = LocalSecurityAuthorshipProof.derive_key_id(public_key)
    envelope = envelope()

    assert {:ok, proof} = LocalSecurityAuthorshipProof.sign(envelope, private_key, key_id)
    assert proof.signer_peer_id == envelope.sender_peer_id
    assert proof.key_id == key_id

    assert {:ok, result} = LocalSecurityAuthorshipProof.verify(envelope, proof, public_key)

    assert result.authorship_proof?
    assert result.algorithm == :ed25519
    assert result.signer_peer_id == envelope.sender_peer_id
    assert result.message_id == envelope.message_id
  end

  test "verification fails when envelope bytes change" do
    {public_key, private_key} = :crypto.generate_key(:eddsa, :ed25519)
    key_id = LocalSecurityAuthorshipProof.derive_key_id(public_key)
    original = envelope(payload: "original")
    tampered = envelope(payload: "tampered")

    assert {:ok, proof} = LocalSecurityAuthorshipProof.sign(original, private_key, key_id)

    assert {:error, :signature_mismatch} =
             LocalSecurityAuthorshipProof.verify(tampered, proof, public_key)
  end

  test "verification fails when signed envelope identity fields change" do
    assert_signed_field_tamper_rejected(:message_id, "message-id-00002", :signature_mismatch)
    assert_signed_field_tamper_rejected(:sender_peer_id, "peer-b", :signer_peer_mismatch)
    assert_signed_field_tamper_rejected(:payload_type, "alert", :signature_mismatch)
    assert_signed_field_tamper_rejected(:payload, "tampered", :signature_mismatch)
  end

  test "verification rejects unsupported tampered envelope versions" do
    {public_key, private_key} = :crypto.generate_key(:eddsa, :ed25519)
    key_id = LocalSecurityAuthorshipProof.derive_key_id(public_key)
    original = envelope()
    tampered = %{original | envelope_version: 2}

    assert {:ok, proof} = LocalSecurityAuthorshipProof.sign(original, private_key, key_id)

    assert {:error, :invalid_envelope} =
             LocalSecurityAuthorshipProof.verify(tampered, proof, public_key)
  end

  test "verification fails when signer peer does not match envelope sender" do
    {public_key, private_key} = :crypto.generate_key(:eddsa, :ed25519)
    key_id = LocalSecurityAuthorshipProof.derive_key_id(public_key)
    envelope = envelope()

    assert {:ok, proof} = LocalSecurityAuthorshipProof.sign(envelope, private_key, key_id)
    mismatched = %{proof | signer_peer_id: "other-peer"}

    assert {:error, :signer_peer_mismatch} =
             LocalSecurityAuthorshipProof.verify(envelope, mismatched, public_key)
  end

  test "malformed proof is rejected before crypto verification" do
    {public_key, _private_key} = :crypto.generate_key(:eddsa, :ed25519)

    proof = %Proof{
      proof_version: 1,
      algorithm: :ed25519,
      key_id: "key-1",
      signer_peer_id: "peer-a",
      signature: <<1, 2, 3>>
    }

    assert {:error, :invalid_signature} =
             LocalSecurityAuthorshipProof.verify(envelope(), proof, public_key)
  end

  test "hash-only beacon refs are outside the authorship proof boundary" do
    assert {:error, :invalid_envelope} =
             LocalSecurityAuthorshipProof.signing_payload(%{
               message_id_hash: <<1::128>>,
               sender_peer_hash: <<2::128>>
             })
  end

  defp envelope(overrides \\ []) do
    attrs =
      [
        message_id: "message-id-00001",
        sender_peer_id: "peer-a",
        recipient_peer_id: nil,
        created_at: 1_700_000_000_000,
        ttl: 4,
        payload_type: "text",
        payload: "hello",
        capability_requirements: 0
      ]
      |> Keyword.merge(overrides)

    assert {:ok, envelope} = MessageEnvelope.build(attrs)
    envelope
  end

  defp assert_signed_field_tamper_rejected(field, value, expected_reason) do
    {public_key, private_key} = :crypto.generate_key(:eddsa, :ed25519)
    key_id = LocalSecurityAuthorshipProof.derive_key_id(public_key)
    original = envelope()
    tampered = envelope([{field, value}])

    assert {:ok, proof} = LocalSecurityAuthorshipProof.sign(original, private_key, key_id)

    assert {:error, ^expected_reason} =
             LocalSecurityAuthorshipProof.verify(tampered, proof, public_key)
  end
end
