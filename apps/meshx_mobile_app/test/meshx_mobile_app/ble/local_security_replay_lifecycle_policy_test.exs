defmodule MeshxMobileApp.BLE.LocalSecurityReplayLifecyclePolicyTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.LocalSecurityReplayLifecyclePolicy

  test "snapshot records memory-only replay lifecycle policy" do
    snapshot = LocalSecurityReplayLifecyclePolicy.snapshot()

    assert snapshot.boundary == :memory_only_replay_lifecycle_policy
    assert snapshot.replay_state_mode == :memory_only
    assert snapshot.restart_behavior == :cleared_on_process_restart
    refute snapshot.durable_replay_state_allowed?
    refute snapshot.restart_surviving_replay_protection_claim_allowed?
    refute snapshot.trusted_delivery_claim_allowed?
    refute snapshot.background_replay_claim_allowed?
    assert :durable_replay_store_policy in snapshot.required_before_durable
    assert :restart_surviving_replay_protection in snapshot.blocked_claims
  end

  test "JSON snapshot preserves blocked durable and delivery claims" do
    snapshot = LocalSecurityReplayLifecyclePolicy.json_snapshot()

    assert snapshot["boundary"] == "memory_only_replay_lifecycle_policy"
    assert snapshot["durable_replay_state_allowed?"] == false
    assert snapshot["trusted_delivery_claim_allowed?"] == false
    assert "durable_replay_state" in snapshot["blocked_claims"]
  end
end
