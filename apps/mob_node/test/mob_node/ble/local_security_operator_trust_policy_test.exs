defmodule Mob.Node.BLE.LocalSecurityOperatorTrustPolicyTest do
  use ExUnit.Case, async: true

  alias Mob.Node.BLE.{
    LocalSecurityOperatorTrustPolicy,
    LocalSecurityPeerIdentityBinding
  }

  test "records explicit operator trust for a supplied peer and key binding" do
    binding = peer_binding("meshx-alpha")
    assert {:ok, policy} = LocalSecurityOperatorTrustPolicy.new()

    assert {:ok, policy} =
             LocalSecurityOperatorTrustPolicy.put(policy, binding, :trusted,
               updated_at: 10,
               reason: "operator paired device"
             )

    assert {:ok, decision} = LocalSecurityOperatorTrustPolicy.evaluate(policy, binding)

    assert decision.operator_trust_policy?
    assert decision.policy_entry_found?
    assert decision.peer_trust_state == :trusted
    assert decision.trusted_peer_state?
    assert decision.peer_id == "meshx-alpha"
    assert decision.key_id == binding.key_id
    assert decision.policy_updated_at == 10
  end

  test "does not transfer trust to the same peer id with different key material" do
    trusted_binding = peer_binding("meshx-alpha")
    other_binding = peer_binding("meshx-alpha")
    assert trusted_binding.key_id != other_binding.key_id

    assert {:ok, policy} =
             LocalSecurityOperatorTrustPolicy.new()
             |> then(fn {:ok, policy} ->
               LocalSecurityOperatorTrustPolicy.put(policy, trusted_binding, :trusted)
             end)

    assert {:ok, decision} = LocalSecurityOperatorTrustPolicy.evaluate(policy, other_binding)

    refute decision.policy_entry_found?
    assert decision.peer_trust_state == :unknown
    refute decision.trusted_peer_state?
  end

  test "blocked and revoked operator states are explicit policy outcomes" do
    binding = peer_binding("meshx-alpha")
    assert {:ok, policy} = LocalSecurityOperatorTrustPolicy.new()

    assert {:ok, blocked_policy} =
             LocalSecurityOperatorTrustPolicy.put(policy, binding, :blocked,
               reason: "operator blocked"
             )

    assert {:ok, blocked} = LocalSecurityOperatorTrustPolicy.evaluate(blocked_policy, binding)
    assert blocked.peer_trust_state == :blocked
    refute blocked.trusted_peer_state?

    assert {:ok, revoked_policy} =
             LocalSecurityOperatorTrustPolicy.put(blocked_policy, binding, :revoked,
               reason: "operator revoked"
             )

    assert {:ok, revoked} = LocalSecurityOperatorTrustPolicy.evaluate(revoked_policy, binding)
    assert revoked.peer_trust_state == :revoked
    refute revoked.trusted_peer_state?
  end

  test "validates entries and update metadata" do
    binding = peer_binding("meshx-alpha")
    assert {:ok, policy} = LocalSecurityOperatorTrustPolicy.new()

    assert {:error, :invalid_peer_trust_state} =
             LocalSecurityOperatorTrustPolicy.put(policy, binding, :unknown)

    assert {:error, :invalid_updated_at} =
             LocalSecurityOperatorTrustPolicy.put(policy, binding, :trusted, updated_at: -1)

    assert {:error, :invalid_reason} =
             LocalSecurityOperatorTrustPolicy.put(policy, binding, :trusted, reason: :paired)

    assert {:error, :invalid_peer_id} =
             LocalSecurityOperatorTrustPolicy.new([
               %{peer_id: "", key_id: <<1>>, peer_trust_state: :trusted}
             ])
  end

  test "JSON snapshot preserves policy entries without changing semantics" do
    binding = peer_binding("meshx-alpha")
    assert {:ok, policy} = LocalSecurityOperatorTrustPolicy.new()
    assert {:ok, policy} = LocalSecurityOperatorTrustPolicy.put(policy, binding, :untrusted)

    snapshot = LocalSecurityOperatorTrustPolicy.json_snapshot(policy)

    assert snapshot["policy_version"] == 1

    assert [%{"peer_trust_state" => "untrusted", "peer_id" => "meshx-alpha"}] =
             snapshot["entries"]
  end

  defp peer_binding(peer_id) do
    {public_key, _private_key} = :crypto.generate_key(:eddsa, :ed25519)
    assert {:ok, binding} = LocalSecurityPeerIdentityBinding.bind(peer_id, public_key)
    binding
  end
end
