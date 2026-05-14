defmodule MeshxMobileApp.BLE.LocalSecurityTrustedMessageDecisionTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.{
    LocalSecurityAuthorshipProof,
    LocalSecurityPeerIdentityBinding,
    LocalSecurityReplayProtection,
    LocalSecurityTrustedMessageDecision,
    MessageEnvelope
  }

  test "trusts a full envelope only when binding, authorship, replay, and trusted peer state are present" do
    fixture = signed_fixture()
    assert {:ok, replay_state} = LocalSecurityReplayProtection.new(window_ms: 1_000)

    assert {:ok, _next_state, decision} =
             LocalSecurityTrustedMessageDecision.decide(
               fixture.envelope,
               fixture.proof,
               fixture.binding,
               replay_state,
               observed_at: 1_100,
               peer_trust_state: :trusted
             )

    assert decision.status == :trusted_message
    assert decision.trusted_message?
    refute decision.trusted_delivery_claim_allowed?
    assert :trusted_delivery in decision.blocked_claims
    assert decision.binding_key_id == fixture.binding.key_id
    assert decision.message_id == fixture.envelope.message_id
  end

  test "keeps unknown and untrusted peers from becoming trusted messages" do
    fixture = signed_fixture()
    assert {:ok, replay_state} = LocalSecurityReplayProtection.new(window_ms: 1_000)

    assert {:ok, _next_state, decision} =
             LocalSecurityTrustedMessageDecision.decide(
               fixture.envelope,
               fixture.proof,
               fixture.binding,
               replay_state,
               observed_at: 1_100,
               peer_trust_state: :unknown
             )

    assert decision.status == :untrusted
    refute decision.trusted_message?
    assert :trusted_peer_state in decision.missing_evidence
  end

  test "blocked and revoked peers override otherwise valid evidence" do
    fixture = signed_fixture()
    assert {:ok, replay_state} = LocalSecurityReplayProtection.new(window_ms: 1_000)

    assert {:ok, _next_state, decision} =
             LocalSecurityTrustedMessageDecision.decide(
               fixture.envelope,
               fixture.proof,
               fixture.binding,
               replay_state,
               observed_at: 1_100,
               peer_trust_state: :revoked
             )

    assert decision.status == :blocked
    refute decision.trusted_message?
    assert :peer_revoked in decision.reasons
  end

  test "rejects duplicate replay before trust evaluation can succeed again" do
    fixture = signed_fixture()
    assert {:ok, replay_state} = LocalSecurityReplayProtection.new(window_ms: 1_000)

    assert {:ok, replay_state, _decision} =
             LocalSecurityTrustedMessageDecision.decide(
               fixture.envelope,
               fixture.proof,
               fixture.binding,
               replay_state,
               observed_at: 1_100,
               peer_trust_state: :trusted
             )

    assert {:error, :duplicate_proof, _state, decision} =
             LocalSecurityTrustedMessageDecision.decide(
               fixture.envelope,
               fixture.proof,
               fixture.binding,
               replay_state,
               observed_at: 1_200,
               peer_trust_state: :trusted
             )

    assert decision.status == :rejected
    refute decision.trusted_message?
    assert decision.reasons == [:duplicate_proof]
  end

  test "rejects key binding mismatch" do
    fixture = signed_fixture()
    {other_public_key, _private_key} = :crypto.generate_key(:eddsa, :ed25519)

    assert {:ok, wrong_binding} =
             LocalSecurityPeerIdentityBinding.bind("meshx-alpha", other_public_key)

    assert {:ok, replay_state} = LocalSecurityReplayProtection.new(window_ms: 1_000)

    assert {:error, :binding_key_mismatch, ^replay_state, decision} =
             LocalSecurityTrustedMessageDecision.decide(
               fixture.envelope,
               fixture.proof,
               wrong_binding,
               replay_state,
               observed_at: 1_100,
               peer_trust_state: :trusted
             )

    assert decision.status == :rejected
    assert :binding_key_mismatch in decision.reasons
  end

  test "beacon refs are outside the trusted-message decision boundary" do
    fixture = signed_fixture()
    assert {:ok, replay_state} = LocalSecurityReplayProtection.new(window_ms: 1_000)

    assert {:error, :invalid_envelope, ^replay_state, decision} =
             LocalSecurityTrustedMessageDecision.decide(
               %{message_id_hash: <<1::64>>, sender_peer_hash: <<2::64>>},
               fixture.proof,
               fixture.binding,
               replay_state,
               observed_at: 1_100,
               peer_trust_state: :trusted
             )

    assert decision.status == :rejected
    refute decision.trusted_message?
  end

  test "proof flags expose only the trusted full-message case" do
    assert %{
             authenticated_peer_identity?: true,
             message_authorship?: true,
             replay_protection?: true,
             peer_trust_state: :trusted
           } =
             LocalSecurityTrustedMessageDecision.proof_flags(%{
               trusted_message?: true,
               peer_trust_state: :trusted
             })

    assert %{authenticated_peer_identity?: false, peer_trust_state: :revoked} =
             LocalSecurityTrustedMessageDecision.proof_flags(%{
               trusted_message?: false,
               peer_trust_state: :revoked
             })
  end

  defp signed_fixture do
    {public_key, private_key} = :crypto.generate_key(:eddsa, :ed25519)
    assert {:ok, binding} = LocalSecurityPeerIdentityBinding.bind("meshx-alpha", public_key)
    envelope = envelope()
    assert {:ok, proof} = LocalSecurityAuthorshipProof.sign(envelope, private_key, binding.key_id)

    %{binding: binding, envelope: envelope, proof: proof}
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
