defmodule Mob.Node.BLE.LocalTrustPolicyTest do
  use ExUnit.Case, async: true

  alias Mob.Node.BLE.{LocalInbox, LocalTrustPolicy, MessageEnvelope}
  alias Mob.Node.BLE.Events.{ReceivedMessage, ReceivedMessageBeacon}

  defp envelope do
    {:ok, envelope} =
      MessageEnvelope.build(
        message_id: <<1::128>>,
        sender_peer_id: "meshx-alpha",
        recipient_peer_id: "meshx-beta",
        created_at: 1_700_000_000_000,
        ttl: 1,
        payload_type: "TX",
        payload: "hello",
        capability_requirements: 0
      )

    envelope
  end

  defp full_event do
    env = envelope()

    %ReceivedMessage{
      message_id: env.message_id,
      sender_peer_id: env.sender_peer_id,
      recipient_peer_id: env.recipient_peer_id,
      received_device_id: "AA:01",
      received_at: 10,
      rssi: -60,
      envelope: env,
      raw_transport_metadata: %{}
    }
  end

  defp beacon_event do
    %ReceivedMessageBeacon{
      beacon_version: 1,
      envelope_version: 1,
      payload_kind: "TX",
      message_id_hash: <<1, 2, 3, 4, 5, 6, 7, 8>>,
      sender_peer_id_hash: <<8, 7, 6, 5, 4, 3, 2, 1>>,
      received_device_id: "AA:02",
      received_at: 10,
      rssi: -70,
      raw_transport_metadata: %{}
    }
  end

  test "full messages may be displayed only as unsigned local observations" do
    snapshot =
      LocalInbox.new()
      |> LocalInbox.ingest(full_event())
      |> LocalInbox.snapshot()

    assert [%LocalTrustPolicy.Decision{} = decision] = snapshot.trust_policy.decisions
    assert decision.presentation == :local_unsigned_message
    refute decision.trusted_message?
    refute decision.delivery_claim_allowed?
    assert :message_authorship in decision.required_before_trusted
    assert :canonical_envelope_without_authorship in decision.reasons
  end

  test "beacon refs remain untrusted references that require full envelope resolution" do
    snapshot =
      LocalInbox.new()
      |> LocalInbox.ingest(beacon_event())
      |> LocalInbox.snapshot()

    assert [%LocalTrustPolicy.Decision{} = decision] = snapshot.trust_policy.decisions
    assert decision.presentation == :local_untrusted_reference
    refute decision.trusted_message?
    refute decision.delivery_claim_allowed?
    assert :full_envelope_resolution in decision.required_before_trusted
    assert :hash_reference_not_authorship in decision.reasons
  end

  test "snapshot exposes aggregate trust policy counts and blocks delivery wording" do
    snapshot =
      LocalInbox.new()
      |> LocalInbox.ingest(full_event())
      |> LocalInbox.ingest(beacon_event())
      |> LocalInbox.snapshot()

    assert snapshot.trust_policy.policy == :advertisement_only_local_trust_policy

    assert snapshot.trust_policy.current_security_decision.decision_outcome ==
             :keep_unsigned_local_observation

    assert snapshot.trust_policy.current_security_decision.decision_status ==
             :selected_for_current_validated_mode

    refute snapshot.trust_policy.current_security_decision.authenticated_peer_identity_enabled?
    refute snapshot.trust_policy.current_security_decision.authenticated_message_enabled?
    refute snapshot.trust_policy.current_security_decision.trusted_message_claim_allowed?
    refute snapshot.trust_policy.current_security_decision.trusted_delivery_claim_allowed?
    assert snapshot.trust_policy.trusted_message_count == 0
    assert snapshot.trust_policy.untrusted_count == 2
    refute snapshot.trust_policy.delivery_claims_allowed?

    assert Enum.any?(
             snapshot.trust_policy.notes,
             &String.contains?(&1, "Trusted-message and delivery wording remain blocked")
           )
  end

  test "empty evidence still blocks delivery wording" do
    snapshot = LocalTrustPolicy.snapshot(%{trust_evidence: []})

    assert snapshot.trusted_message_count == 0
    assert snapshot.untrusted_count == 0
    refute snapshot.delivery_claims_allowed?
  end
end
