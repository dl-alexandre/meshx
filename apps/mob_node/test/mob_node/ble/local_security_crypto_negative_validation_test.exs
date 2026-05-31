defmodule Mob.Node.BLE.LocalSecurityCryptoNegativeValidationTest do
  use ExUnit.Case, async: true

  alias Mob.Node.BLE.{
    LocalSecurityAuthorshipProof,
    LocalSecurityCryptoNegativeValidation,
    LocalSecurityOperatorTrustPolicy,
    LocalSecurityPeerIdentityBinding,
    LocalSecurityReplayProtection,
    MessageEnvelope,
    Replay
  }

  alias Mob.Node.BLE.Events.ReceivedMessage

  @fixtures Path.expand("../../fixtures/captures", __DIR__)

  test "all required crypto-backed negative cases block trusted-message promotion" do
    validation = LocalSecurityCryptoNegativeValidation.evaluate_cases(required_cases())

    assert validation.boundary == :crypto_backed_local_security_negative_validation
    assert validation.all_required_cases_present?
    assert validation.missing_case_ids == []

    assert validation.case_count ==
             length(LocalSecurityCryptoNegativeValidation.required_case_ids())

    assert validation.failed_count == 0
    refute validation.trusted_claims_allowed?
    refute validation.delivery_claims_allowed?

    assert Enum.all?(validation.cases, & &1.passed?)
    assert Enum.all?(validation.cases, &(not &1.trusted_message?))
    assert Enum.all?(validation.cases, &(not &1.trusted_delivery_claim_allowed?))
  end

  test "reports missing or malformed negative validation cases explicitly" do
    [first | _] = required_cases()
    validation = LocalSecurityCryptoNegativeValidation.evaluate_cases([first, %{id: :malformed}])

    refute validation.all_required_cases_present?
    assert :signature_mismatch in validation.missing_case_ids
    assert validation.failed_count == 1

    malformed = Enum.find(validation.cases, &(&1.id == :malformed))
    refute malformed.passed?
    assert malformed.actual_reasons == [:invalid_negative_validation_case]
  end

  test "passive labels and stale refs are executable negative cases" do
    validation = LocalSecurityCryptoNegativeValidation.evaluate_cases(required_cases())

    for case_id <- [:passive_peer_label, :stale_beacon_ref] do
      result = Enum.find(validation.cases, &(&1.id == case_id))

      assert result.passed?
      assert result.expected_reason == :invalid_received_message
      assert :invalid_received_message in result.actual_reasons
      refute result.trusted_message?
      refute result.trusted_delivery_claim_allowed?
    end
  end

  test "operator trusted policy must match the supplied peer binding" do
    validation = LocalSecurityCryptoNegativeValidation.evaluate_cases(required_cases())
    result = Enum.find(validation.cases, &(&1.id == :trusted_policy_without_matching_binding))

    assert result.passed?
    assert result.actual_status == :untrusted
    assert result.expected_reason == :trusted_peer_state
    assert :trusted_peer_state in result.actual_reasons
    refute result.trusted_message?
    refute result.trusted_delivery_claim_allowed?
  end

  defp required_cases do
    event = replay_message_event()
    trusted = signed_fixture(event)
    mismatched = signed_fixture(event)
    blocked_policy = operator_policy(trusted.binding, :blocked)
    revoked_policy = operator_policy(trusted.binding, :revoked)

    [
      %{
        id: :tampered_transport_payload,
        initial_replay_state: replay_state(),
        expected_status: :rejected,
        expected_reason: :transport_payload_mismatch,
        attempts: [
          %{
            event:
              event
              |> Map.update!(:raw_transport_metadata, &Map.put(&1, :message_payload, <<"bad">>)),
            proof: trusted.proof,
            binding: trusted.binding,
            opts: trusted_opts(event, trusted.policy)
          }
        ]
      },
      %{
        id: :signature_mismatch,
        initial_replay_state: replay_state(),
        expected_status: :rejected,
        expected_reason: :signature_mismatch,
        attempts: [
          %{
            event: altered_event(event),
            proof: trusted.proof,
            binding: trusted.binding,
            opts: trusted_opts(event, trusted.policy)
          }
        ]
      },
      %{
        id: :binding_key_mismatch,
        initial_replay_state: replay_state(),
        expected_status: :rejected,
        expected_reason: :binding_key_mismatch,
        attempts: [
          %{
            event: event,
            proof: trusted.proof,
            binding: mismatched.binding,
            opts: trusted_opts(event, trusted.policy)
          }
        ]
      },
      %{
        id: :duplicate_replay,
        initial_replay_state: replay_state(),
        expected_status: :rejected,
        expected_reason: :duplicate_proof,
        attempts: [
          %{
            event: event,
            proof: trusted.proof,
            binding: trusted.binding,
            opts: trusted_opts(event, trusted.policy)
          },
          %{
            event: event,
            proof: trusted.proof,
            binding: trusted.binding,
            opts:
              Keyword.put(
                trusted_opts(event, trusted.policy),
                :observed_at,
                event.envelope.created_at + 200
              )
          }
        ]
      },
      %{
        id: :trusted_policy_without_matching_binding,
        initial_replay_state: replay_state(),
        expected_status: :untrusted,
        expected_reason: :trusted_peer_state,
        attempts: [
          %{
            event: event,
            proof: trusted.proof,
            binding: trusted.binding,
            opts: trusted_opts(event, operator_policy(mismatched.binding, :trusted))
          }
        ]
      },
      %{
        id: :blocked_peer_policy,
        initial_replay_state: replay_state(),
        expected_status: :blocked,
        expected_reason: :peer_blocked,
        attempts: [
          %{
            event: event,
            proof: trusted.proof,
            binding: trusted.binding,
            opts: trusted_opts(event, blocked_policy)
          }
        ]
      },
      %{
        id: :revoked_peer_policy,
        initial_replay_state: replay_state(),
        expected_status: :blocked,
        expected_reason: :peer_revoked,
        attempts: [
          %{
            event: event,
            proof: trusted.proof,
            binding: trusted.binding,
            opts: trusted_opts(event, revoked_policy)
          }
        ]
      },
      %{
        id: :hash_only_beacon_ref,
        initial_replay_state: replay_state(),
        expected_status: :rejected,
        expected_reason: :invalid_received_message,
        attempts: [
          %{
            event: legacy_beacon_event(),
            proof: trusted.proof,
            binding: trusted.binding,
            opts: trusted_opts(event, trusted.policy)
          }
        ]
      },
      %{
        id: :passive_peer_label,
        initial_replay_state: replay_state(),
        expected_status: :rejected,
        expected_reason: :invalid_received_message,
        attempts: [
          %{
            event: %{
              advertised_name: "mob-passive-peer",
              device_id: "passive-device",
              observed_at: event.received_at
            },
            proof: trusted.proof,
            binding: trusted.binding,
            opts: trusted_opts(event, trusted.policy)
          }
        ]
      },
      %{
        id: :stale_beacon_ref,
        initial_replay_state: replay_state(),
        expected_status: :rejected,
        expected_reason: :invalid_received_message,
        attempts: [
          %{
            event: %{legacy_beacon_event() | received_at: 1},
            proof: trusted.proof,
            binding: trusted.binding,
            opts: trusted_opts(event, trusted.policy)
          }
        ]
      }
    ]
  end

  defp replay_message_event do
    assert [%ReceivedMessage{} = event] = Replay.load!(fixture("message_advertisement.jsonl"))
    event
  end

  defp legacy_beacon_event do
    assert [event] = Replay.load!(fixture("legacy_beacon_advertisement.jsonl"))
    event
  end

  defp signed_fixture(%ReceivedMessage{envelope: envelope}) do
    {public_key, private_key} = :crypto.generate_key(:eddsa, :ed25519)

    assert {:ok, binding} =
             LocalSecurityPeerIdentityBinding.bind(envelope.sender_peer_id, public_key)

    assert {:ok, proof} = LocalSecurityAuthorshipProof.sign(envelope, private_key, binding.key_id)
    policy = operator_policy(binding, :trusted)

    %{binding: binding, proof: proof, policy: policy}
  end

  defp operator_policy(binding, peer_trust_state) do
    assert {:ok, policy} = LocalSecurityOperatorTrustPolicy.new()
    assert {:ok, policy} = LocalSecurityOperatorTrustPolicy.put(policy, binding, peer_trust_state)
    policy
  end

  defp replay_state do
    assert {:ok, replay_state} = LocalSecurityReplayProtection.new(window_ms: 20_000)
    replay_state
  end

  defp trusted_opts(%ReceivedMessage{} = event, policy) do
    [
      observed_at: event.envelope.created_at + 100,
      operator_trust_policy: policy
    ]
  end

  defp altered_event(%ReceivedMessage{} = event) do
    assert {:ok, envelope} =
             MessageEnvelope.build(
               message_id: event.envelope.message_id,
               sender_peer_id: event.envelope.sender_peer_id,
               recipient_peer_id: event.envelope.recipient_peer_id,
               created_at: event.envelope.created_at,
               ttl: event.envelope.ttl,
               payload_type: event.envelope.payload_type,
               payload: "tampered",
               capability_requirements: event.envelope.capability_requirements
             )

    %{event | envelope: envelope, raw_transport_metadata: %{}}
  end

  defp fixture(name), do: Path.join(@fixtures, name)
end
