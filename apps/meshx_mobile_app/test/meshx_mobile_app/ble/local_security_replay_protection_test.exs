defmodule MeshxMobileApp.BLE.LocalSecurityReplayProtectionTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.{
    LocalSecurityAuthorshipProof,
    LocalSecurityReplayProtection,
    MessageEnvelope
  }

  alias MeshxMobileApp.BLE.LocalSecurityAuthorshipProof.Proof

  test "accepts a fresh verified full-envelope proof once" do
    {envelope, proof} = signed_envelope(created_at: 1_000)
    assert {:ok, state} = LocalSecurityReplayProtection.new(window_ms: 500, max_entries: 4)

    assert {:ok, next, evidence} =
             LocalSecurityReplayProtection.accept(state, envelope, proof, observed_at: 1_200)

    assert evidence.replay_protection?
    assert evidence.replay_decision == :accepted
    assert evidence.expires_at == 1_500
    assert length(next.seen) == 1
  end

  test "rejects duplicate proof inside the replay window" do
    {envelope, proof} = signed_envelope(created_at: 1_000)
    assert {:ok, state} = LocalSecurityReplayProtection.new(window_ms: 500)

    assert {:ok, next, _evidence} =
             LocalSecurityReplayProtection.accept(state, envelope, proof, observed_at: 1_100)

    assert {:error, :duplicate_proof, _state} =
             LocalSecurityReplayProtection.accept(next, envelope, proof, observed_at: 1_200)
  end

  test "rejects expired envelope proofs" do
    {envelope, proof} = signed_envelope(created_at: 1_000)
    assert {:ok, state} = LocalSecurityReplayProtection.new(window_ms: 500)

    assert {:error, :expired_envelope, ^state} =
             LocalSecurityReplayProtection.accept(state, envelope, proof, observed_at: 1_501)
  end

  test "prunes old seen proofs and bounds retained entries" do
    assert {:ok, state} = LocalSecurityReplayProtection.new(window_ms: 1_000, max_entries: 2)
    {first, first_proof} = signed_envelope(message_id: "message-id-00001", created_at: 1_000)
    {second, second_proof} = signed_envelope(message_id: "message-id-00002", created_at: 1_100)
    {third, third_proof} = signed_envelope(message_id: "message-id-00003", created_at: 1_200)

    assert {:ok, state, _} =
             LocalSecurityReplayProtection.accept(state, first, first_proof, observed_at: 1_000)

    assert {:ok, state, _} =
             LocalSecurityReplayProtection.accept(state, second, second_proof, observed_at: 1_100)

    assert {:ok, state, _} =
             LocalSecurityReplayProtection.accept(state, third, third_proof, observed_at: 1_200)

    assert Enum.map(state.seen, & &1.message_id) == ["message-id-00003", "message-id-00002"]

    pruned = LocalSecurityReplayProtection.prune(state, 2_201)
    assert pruned.seen == []
  end

  test "fingerprint binds envelope bytes, key id, and signature" do
    {envelope, proof} = signed_envelope(message_id: "message-id-00001", payload: "one")
    {changed, changed_proof} = signed_envelope(message_id: "message-id-00001", payload: "two")

    refute LocalSecurityReplayProtection.fingerprint(envelope, proof) ==
             LocalSecurityReplayProtection.fingerprint(changed, changed_proof)
  end

  test "rejects malformed inputs and invalid policy bounds" do
    assert {:error, :invalid_window} = LocalSecurityReplayProtection.new(window_ms: 0)
    assert {:error, :invalid_max_entries} = LocalSecurityReplayProtection.new(max_entries: 0)

    {envelope, _proof} = signed_envelope()
    assert {:ok, state} = LocalSecurityReplayProtection.new()

    malformed = %Proof{
      proof_version: 1,
      algorithm: :ed25519,
      key_id: "key-1",
      signer_peer_id: "meshx-alpha",
      signature: <<1, 2, 3>>
    }

    assert {:error, :invalid_proof, ^state} =
             LocalSecurityReplayProtection.accept(state, envelope, malformed, observed_at: 1_000)

    assert {:error, :invalid_observed_at, ^state} =
             LocalSecurityReplayProtection.accept(state, envelope, malformed, observed_at: nil)
  end

  test "hash-only beacon refs are outside the replay guard boundary" do
    {_envelope, proof} = signed_envelope()
    assert {:ok, state} = LocalSecurityReplayProtection.new()

    assert {:error, :invalid_envelope, ^state} =
             LocalSecurityReplayProtection.accept(
               state,
               %{message_id_hash: <<1::64>>, sender_peer_hash: <<2::64>>},
               proof,
               observed_at: 1_000
             )
  end

  defp signed_envelope(overrides \\ []) do
    {public_key, private_key} = :crypto.generate_key(:eddsa, :ed25519)
    key_id = LocalSecurityAuthorshipProof.derive_key_id(public_key)
    envelope = envelope(overrides)

    assert {:ok, proof} = LocalSecurityAuthorshipProof.sign(envelope, private_key, key_id)
    {envelope, proof}
  end

  defp envelope(overrides) do
    attrs =
      [
        message_id: Keyword.get(overrides, :message_id, "message-id-00001"),
        sender_peer_id: "meshx-alpha",
        recipient_peer_id: nil,
        created_at: Keyword.get(overrides, :created_at, 1_000),
        ttl: 4,
        payload_type: "text",
        payload: Keyword.get(overrides, :payload, "hello"),
        capability_requirements: 0
      ]

    assert {:ok, envelope} = MessageEnvelope.build(attrs)
    envelope
  end
end
