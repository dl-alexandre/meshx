defmodule Mob.Node.BLE.LocalSecurityCanonicalReplayDecisionTest do
  use ExUnit.Case, async: true

  alias Mob.Node.BLE.{
    LocalSecurityAuthorshipProof,
    LocalSecurityCanonicalReplayDecision,
    LocalSecurityOperatorTrustPolicy,
    LocalSecurityPeerIdentityBinding,
    LocalSecurityReplayProtection,
    Replay
  }

  alias Mob.Node.BLE.Events.ReceivedMessage

  @fixtures Path.expand("../../fixtures/captures", __DIR__)

  test "trusts a replay-normalized ReceivedMessage only with supplied proof, binding, replay, and trust evidence" do
    event = replay_message_event()
    fixture = signed_fixture(event)
    assert {:ok, replay_state} = LocalSecurityReplayProtection.new(window_ms: 20_000)

    assert {:ok, _next_state, decision} =
             LocalSecurityCanonicalReplayDecision.decide(
               event,
               fixture.proof,
               fixture.binding,
               replay_state,
               observed_at: event.envelope.created_at + 100,
               peer_trust_state: :trusted
             )

    assert decision.canonical_replay_event?
    assert decision.status == :trusted_message
    assert decision.trusted_message?
    refute decision.trusted_delivery_claim_allowed?
    assert decision.received_device_id == "AA:BB:CC:DD:EE:01"
    assert decision.received_at == 12_345
    assert decision.rssi == -61
    assert :trusted_delivery in decision.blocked_claims
  end

  test "keeps replay-normalized messages untrusted without explicit trusted peer state" do
    event = replay_message_event()
    fixture = signed_fixture(event)
    assert {:ok, replay_state} = LocalSecurityReplayProtection.new(window_ms: 20_000)

    assert {:ok, _next_state, decision} =
             LocalSecurityCanonicalReplayDecision.decide(
               event,
               fixture.proof,
               fixture.binding,
               replay_state,
               observed_at: event.envelope.created_at + 100,
               peer_trust_state: :unknown
             )

    assert decision.canonical_replay_event?
    assert decision.status == :untrusted
    refute decision.trusted_message?
    assert :trusted_peer_state in decision.missing_evidence
  end

  test "derives peer trust state from an explicit operator trust policy" do
    event = replay_message_event()
    fixture = signed_fixture(event)
    assert {:ok, replay_state} = LocalSecurityReplayProtection.new(window_ms: 20_000)

    assert {:ok, trust_policy} =
             LocalSecurityOperatorTrustPolicy.new()
             |> then(fn {:ok, policy} ->
               LocalSecurityOperatorTrustPolicy.put(policy, fixture.binding, :trusted,
                 reason: "operator trusted fixture key"
               )
             end)

    assert {:ok, _next_state, decision} =
             LocalSecurityCanonicalReplayDecision.decide(
               event,
               fixture.proof,
               fixture.binding,
               replay_state,
               observed_at: event.envelope.created_at + 100,
               operator_trust_policy: trust_policy
             )

    assert decision.status == :trusted_message
    assert decision.trusted_message?
    assert decision.operator_trust_policy?
    assert decision.policy_entry_found?
    assert decision.policy_reason == "operator trusted fixture key"
  end

  test "keeps messages untrusted when the operator policy has no matching peer/key entry" do
    event = replay_message_event()
    fixture = signed_fixture(event)
    other_fixture = signed_fixture(event)
    assert fixture.binding.key_id != other_fixture.binding.key_id
    assert {:ok, replay_state} = LocalSecurityReplayProtection.new(window_ms: 20_000)

    assert {:ok, trust_policy} =
             LocalSecurityOperatorTrustPolicy.new()
             |> then(fn {:ok, policy} ->
               LocalSecurityOperatorTrustPolicy.put(policy, other_fixture.binding, :trusted)
             end)

    assert {:ok, _next_state, decision} =
             LocalSecurityCanonicalReplayDecision.decide(
               event,
               fixture.proof,
               fixture.binding,
               replay_state,
               observed_at: event.envelope.created_at + 100,
               operator_trust_policy: trust_policy
             )

    assert decision.status == :untrusted
    refute decision.trusted_message?
    assert decision.operator_trust_policy?
    refute decision.policy_entry_found?
    assert :trusted_peer_state in decision.missing_evidence
  end

  test "operator blocked policy prevents a trusted-message decision" do
    event = replay_message_event()
    fixture = signed_fixture(event)
    assert {:ok, replay_state} = LocalSecurityReplayProtection.new(window_ms: 20_000)

    assert {:ok, trust_policy} =
             LocalSecurityOperatorTrustPolicy.new()
             |> then(fn {:ok, policy} ->
               LocalSecurityOperatorTrustPolicy.put(policy, fixture.binding, :blocked)
             end)

    assert {:ok, _next_state, decision} =
             LocalSecurityCanonicalReplayDecision.decide(
               event,
               fixture.proof,
               fixture.binding,
               replay_state,
               observed_at: event.envelope.created_at + 100,
               operator_trust_policy: trust_policy
             )

    assert decision.status == :blocked
    refute decision.trusted_message?
    assert :peer_blocked in decision.reasons
  end

  test "rejects duplicate replay of the same canonical message proof" do
    event = replay_message_event()
    fixture = signed_fixture(event)
    assert {:ok, replay_state} = LocalSecurityReplayProtection.new(window_ms: 20_000)

    assert {:ok, replay_state, _decision} =
             LocalSecurityCanonicalReplayDecision.decide(
               event,
               fixture.proof,
               fixture.binding,
               replay_state,
               observed_at: event.envelope.created_at + 100,
               peer_trust_state: :trusted
             )

    assert {:error, :duplicate_proof, _state, decision} =
             LocalSecurityCanonicalReplayDecision.decide(
               event,
               fixture.proof,
               fixture.binding,
               replay_state,
               observed_at: event.envelope.created_at + 200,
               peer_trust_state: :trusted
             )

    assert decision.canonical_replay_event?
    assert decision.status == :rejected
    refute decision.trusted_message?
    assert decision.reasons == [:duplicate_proof]
  end

  test "rejects replay events whose envelope and canonical fields diverge" do
    event = %{replay_message_event() | sender_peer_id: "mob-other"}
    fixture = signed_fixture(replay_message_event())
    assert {:ok, replay_state} = LocalSecurityReplayProtection.new(window_ms: 20_000)

    assert {:error, :event_envelope_mismatch, ^replay_state, decision} =
             LocalSecurityCanonicalReplayDecision.decide(
               event,
               fixture.proof,
               fixture.binding,
               replay_state,
               peer_trust_state: :trusted
             )

    refute decision.canonical_replay_event?
    refute decision.trusted_message?
    assert :event_envelope_mismatch in decision.reasons
  end

  test "rejects replay events whose message id diverges from the envelope" do
    event = %{replay_message_event() | message_id: <<9::128>>}
    fixture = signed_fixture(replay_message_event())
    assert {:ok, replay_state} = LocalSecurityReplayProtection.new(window_ms: 20_000)

    assert {:error, :event_envelope_mismatch, ^replay_state, decision} =
             LocalSecurityCanonicalReplayDecision.decide(
               event,
               fixture.proof,
               fixture.binding,
               replay_state,
               peer_trust_state: :trusted
             )

    refute decision.canonical_replay_event?
    refute decision.trusted_message?
    assert :event_envelope_mismatch in decision.reasons
  end

  test "rejects replay events whose recipient diverges from the envelope" do
    event = %{replay_message_event() | recipient_peer_id: "mob-recipient-other"}
    fixture = signed_fixture(replay_message_event())
    assert {:ok, replay_state} = LocalSecurityReplayProtection.new(window_ms: 20_000)

    assert {:error, :event_envelope_mismatch, ^replay_state, decision} =
             LocalSecurityCanonicalReplayDecision.decide(
               event,
               fixture.proof,
               fixture.binding,
               replay_state,
               peer_trust_state: :trusted
             )

    refute decision.canonical_replay_event?
    refute decision.trusted_message?
    assert :event_envelope_mismatch in decision.reasons
  end

  test "rejects transport metadata that does not match the canonical envelope payload" do
    event =
      replay_message_event()
      |> Map.update!(:raw_transport_metadata, &Map.put(&1, :message_payload, <<"bad">>))

    fixture = signed_fixture(replay_message_event())
    assert {:ok, replay_state} = LocalSecurityReplayProtection.new(window_ms: 20_000)

    assert {:error, :transport_payload_mismatch, ^replay_state, decision} =
             LocalSecurityCanonicalReplayDecision.decide(
               event,
               fixture.proof,
               fixture.binding,
               replay_state,
               peer_trust_state: :trusted
             )

    refute decision.canonical_replay_event?
    refute decision.trusted_message?
  end

  test "rejects legacy beacon replay events as pointer refs, not trusted full messages" do
    [beacon] = Replay.load!(fixture("legacy_beacon_advertisement.jsonl"))
    event = replay_message_event()
    fixture = signed_fixture(event)
    assert {:ok, replay_state} = LocalSecurityReplayProtection.new(window_ms: 20_000)

    assert {:error, :invalid_received_message, ^replay_state, decision} =
             LocalSecurityCanonicalReplayDecision.decide(
               beacon,
               fixture.proof,
               fixture.binding,
               replay_state,
               peer_trust_state: :trusted
             )

    refute decision.canonical_replay_event?
    refute decision.trusted_message?
    assert :invalid_received_message in decision.reasons
  end

  defp replay_message_event do
    assert [%ReceivedMessage{} = event] = Replay.load!(fixture("message_advertisement.jsonl"))
    event
  end

  defp signed_fixture(%ReceivedMessage{envelope: envelope}) do
    {public_key, private_key} = :crypto.generate_key(:eddsa, :ed25519)

    assert {:ok, binding} =
             LocalSecurityPeerIdentityBinding.bind(envelope.sender_peer_id, public_key)

    assert {:ok, proof} = LocalSecurityAuthorshipProof.sign(envelope, private_key, binding.key_id)

    %{binding: binding, proof: proof}
  end

  defp fixture(name), do: Path.join(@fixtures, name)
end
