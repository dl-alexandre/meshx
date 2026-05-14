defmodule MeshxMobileApp.BLE.LocalSecurityPeerIdentityBindingTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.{
    LocalSecurityAuthorshipProof,
    LocalSecurityPeerIdentityBinding,
    MessageEnvelope
  }

  test "binds a peer id to supplied Ed25519 public key material" do
    {public_key, _private_key} = :crypto.generate_key(:eddsa, :ed25519)

    assert {:ok, binding} = LocalSecurityPeerIdentityBinding.bind("meshx-alpha", public_key)

    assert binding.binding_version == 1
    assert binding.source == :ed25519_public_key
    assert binding.peer_id == "meshx-alpha"
    assert binding.public_key == public_key
    assert binding.key_id == LocalSecurityAuthorshipProof.derive_key_id(public_key)
  end

  test "verifies authorship proof through the peer identity binding" do
    {public_key, private_key} = :crypto.generate_key(:eddsa, :ed25519)
    envelope = envelope()

    assert {:ok, binding} = LocalSecurityPeerIdentityBinding.bind("meshx-alpha", public_key)
    assert {:ok, proof} = LocalSecurityAuthorshipProof.sign(envelope, private_key, binding.key_id)

    assert {:ok, result} = LocalSecurityPeerIdentityBinding.verify(envelope, proof, binding)

    assert result.authorship_proof?
    assert result.authenticated_peer_identity?
    assert result.signer_peer_id == "meshx-alpha"
    assert result.binding_key_id == binding.key_id
  end

  test "rejects proof key id that does not match the binding key" do
    {public_key, private_key} = :crypto.generate_key(:eddsa, :ed25519)
    {_other_public_key, other_private_key} = :crypto.generate_key(:eddsa, :ed25519)
    envelope = envelope()

    assert {:ok, binding} = LocalSecurityPeerIdentityBinding.bind("meshx-alpha", public_key)

    assert {:ok, proof} =
             LocalSecurityAuthorshipProof.sign(envelope, private_key, "different-key")

    assert {:error, :binding_key_mismatch} =
             LocalSecurityPeerIdentityBinding.verify(envelope, proof, binding)

    assert {:ok, other_proof} =
             LocalSecurityAuthorshipProof.sign(envelope, other_private_key, binding.key_id)

    assert {:error, :signature_mismatch} =
             LocalSecurityPeerIdentityBinding.verify(envelope, other_proof, binding)
  end

  test "rejects binding peer id that does not match the envelope sender" do
    {public_key, private_key} = :crypto.generate_key(:eddsa, :ed25519)
    envelope = envelope()

    assert {:ok, binding} = LocalSecurityPeerIdentityBinding.bind("meshx-beta", public_key)
    assert {:ok, proof} = LocalSecurityAuthorshipProof.sign(envelope, private_key, binding.key_id)

    assert {:error, :binding_peer_mismatch} =
             LocalSecurityPeerIdentityBinding.verify(envelope, proof, binding)
  end

  test "rejects malformed binding material" do
    assert {:error, :invalid_peer_id} = LocalSecurityPeerIdentityBinding.bind("", <<0::256>>)

    assert {:error, :invalid_public_key} =
             LocalSecurityPeerIdentityBinding.bind("meshx-alpha", <<1, 2>>)
  end

  test "binding proof does not authenticate beacon refs or claim delivery" do
    {public_key, _private_key} = :crypto.generate_key(:eddsa, :ed25519)
    assert {:ok, binding} = LocalSecurityPeerIdentityBinding.bind("meshx-alpha", public_key)

    assert {:error, :invalid_peer_id} =
             LocalSecurityPeerIdentityBinding.verify(
               %{message_id_hash: <<1::64>>, sender_peer_hash: <<2::64>>},
               %{},
               binding
             )
  end

  defp envelope(overrides \\ []) do
    attrs =
      [
        message_id: "message-id-00001",
        sender_peer_id: "meshx-alpha",
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
end
