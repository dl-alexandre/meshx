defmodule Mob.Node.BLE.LocalSecurityReplayLifecycleValidation do
  @moduledoc """
  Executable validation for the current memory-only replay lifecycle policy.

  The validation proves duplicate proofs are rejected inside one in-memory
  replay state, old entries prune out of the configured window, and a fresh
  state after restart has no durable memory of prior proofs. It does not
  persist replay state, verify signatures, fetch, route, ACK, retry, encrypt,
  or run background work.
  """

  alias Mob.Node.BLE.{
    LocalSecurityAuthorshipProof,
    LocalSecurityReplayLifecyclePolicy,
    LocalSecurityReplayProtection,
    MessageEnvelope
  }

  @required_case_ids [
    :duplicate_rejected_in_memory,
    :window_prunes_old_entries,
    :restart_clears_replay_state,
    :expired_envelope_rejected,
    :beacon_ref_outside_replay_guard
  ]

  @blocked_claims [
    :durable_replay_state,
    :restart_surviving_replay_protection,
    :trusted_delivery,
    :guaranteed_delivery,
    :background_operation
  ]

  @spec required_case_ids() :: [atom()]
  def required_case_ids, do: @required_case_ids

  @spec snapshot() :: map()
  def snapshot do
    cases = run_cases()
    observed_ids = Enum.map(cases, & &1.id)
    missing_case_ids = @required_case_ids -- observed_ids
    policy = LocalSecurityReplayLifecyclePolicy.snapshot()

    %{
      validation_version: 1,
      boundary: :memory_only_replay_lifecycle_validation,
      policy: policy,
      case_count: length(cases),
      passed_count: Enum.count(cases, & &1.passed?),
      failed_count: Enum.count(cases, &(not &1.passed?)),
      required_case_ids: @required_case_ids,
      missing_case_ids: missing_case_ids,
      all_required_cases_present?: missing_case_ids == [],
      all_cases_passed?: Enum.all?(cases, & &1.passed?),
      durable_replay_state_allowed?: false,
      restart_surviving_replay_protection_claim_allowed?: false,
      trusted_delivery_claim_allowed?: false,
      blocked_claims: @blocked_claims,
      cases: cases,
      notes: [
        "Validation covers memory-only replay lifecycle behavior.",
        "Restart clearing is an explicit limitation, not production durable replay evidence.",
        "Replay lifecycle validation does not authenticate beacon refs or prove delivery."
      ]
    }
  end

  @spec json_snapshot() :: map()
  def json_snapshot do
    snapshot()
    |> JSON.encode!()
    |> JSON.decode!()
  end

  defp run_cases do
    {envelope, proof} = signed_envelope(created_at: 1_000)

    [
      duplicate_rejected_case(envelope, proof),
      window_prunes_case(),
      restart_clears_case(envelope, proof),
      expired_envelope_case(envelope, proof),
      beacon_ref_case(proof)
    ]
  end

  defp duplicate_rejected_case(envelope, proof) do
    with {:ok, state} <- LocalSecurityReplayProtection.new(window_ms: 500),
         {:ok, state, _evidence} <-
           LocalSecurityReplayProtection.accept(state, envelope, proof, observed_at: 1_100),
         {:error, :duplicate_proof, _state} <-
           LocalSecurityReplayProtection.accept(state, envelope, proof, observed_at: 1_200) do
      case_result(:duplicate_rejected_in_memory, true, :duplicate_proof, :duplicate_proof)
    else
      other -> case_result(:duplicate_rejected_in_memory, false, :duplicate_proof, other)
    end
  end

  defp window_prunes_case do
    {first, first_proof} = signed_envelope(message_id: "message-id-00001", created_at: 1_000)
    {second, second_proof} = signed_envelope(message_id: "message-id-00002", created_at: 1_100)

    with {:ok, state} <- LocalSecurityReplayProtection.new(window_ms: 100, max_entries: 4),
         {:ok, state, _} <-
           LocalSecurityReplayProtection.accept(state, first, first_proof, observed_at: 1_000),
         {:ok, state, _} <-
           LocalSecurityReplayProtection.accept(state, second, second_proof, observed_at: 1_100) do
      pruned = LocalSecurityReplayProtection.prune(state, 1_201)
      case_result(:window_prunes_old_entries, pruned.seen == [], :empty_seen, pruned.seen)
    else
      other -> case_result(:window_prunes_old_entries, false, :empty_seen, other)
    end
  end

  defp restart_clears_case(envelope, proof) do
    with {:ok, state} <- LocalSecurityReplayProtection.new(window_ms: 500),
         {:ok, _state, _evidence} <-
           LocalSecurityReplayProtection.accept(state, envelope, proof, observed_at: 1_100),
         {:ok, restarted} <- LocalSecurityReplayProtection.new(window_ms: 500) do
      case_result(:restart_clears_replay_state, restarted.seen == [], :empty_seen, restarted.seen)
    else
      other -> case_result(:restart_clears_replay_state, false, :empty_seen, other)
    end
  end

  defp expired_envelope_case(envelope, proof) do
    with {:ok, state} <- LocalSecurityReplayProtection.new(window_ms: 500),
         {:error, :expired_envelope, _state} <-
           LocalSecurityReplayProtection.accept(state, envelope, proof, observed_at: 1_501) do
      case_result(:expired_envelope_rejected, true, :expired_envelope, :expired_envelope)
    else
      other -> case_result(:expired_envelope_rejected, false, :expired_envelope, other)
    end
  end

  defp beacon_ref_case(proof) do
    with {:ok, state} <- LocalSecurityReplayProtection.new(window_ms: 500),
         {:error, :invalid_envelope, _state} <-
           LocalSecurityReplayProtection.accept(
             state,
             %{message_id_hash: <<1::64>>, sender_peer_hash: <<2::64>>},
             proof,
             observed_at: 1_100
           ) do
      case_result(:beacon_ref_outside_replay_guard, true, :invalid_envelope, :invalid_envelope)
    else
      other -> case_result(:beacon_ref_outside_replay_guard, false, :invalid_envelope, other)
    end
  end

  defp case_result(id, passed?, expected, actual) do
    %{
      id: id,
      passed?: passed?,
      expected: expected,
      actual: actual,
      durable_replay_state?: false,
      trusted_delivery_claim_allowed?: false,
      blocked_claims: @blocked_claims,
      notes: [
        "Replay lifecycle case is scoped to memory-only replay state.",
        "Case does not enable trusted-delivery or durable replay claims."
      ]
    }
  end

  defp signed_envelope(overrides) do
    {public_key, private_key} = fixture_ed25519_keypair()
    key_id = LocalSecurityAuthorshipProof.derive_key_id(public_key)
    envelope = envelope(overrides)

    case LocalSecurityAuthorshipProof.sign(envelope, private_key, key_id) do
      {:ok, proof} -> {envelope, proof}
      {:error, reason} -> raise "signed_envelope fixture failed: #{inspect(reason)}"
    end
  end

  # Deterministic 32-byte seed so fixture signing works on device OTP as well as host.
  defp fixture_ed25519_keypair do
    seed = :crypto.hash(:sha256, "mob_node_replay_fixture_v1") |> binary_part(0, 32)
    :crypto.generate_key(:eddsa, :ed25519, seed)
  end

  defp envelope(overrides) do
    attrs = [
      message_id: Keyword.get(overrides, :message_id, "message-id-00001"),
      sender_peer_id: "meshx-alpha",
      recipient_peer_id: nil,
      created_at: Keyword.get(overrides, :created_at, 1_000),
      ttl: 4,
      payload_type: "text",
      payload: Keyword.get(overrides, :payload, "hello"),
      capability_requirements: 0
    ]

    {:ok, envelope} = MessageEnvelope.build(attrs)
    envelope
  end
end
