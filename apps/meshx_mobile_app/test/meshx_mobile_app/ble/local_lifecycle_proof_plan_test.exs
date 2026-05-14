defmodule MeshxMobileApp.BLE.LocalLifecycleProofPlanTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.LocalLifecycleProofPlan

  test "snapshot maps every background lifecycle requirement to a proof gate" do
    snapshot = LocalLifecycleProofPlan.snapshot()
    ids = Enum.map(snapshot.gates, & &1.requirement_id)

    assert snapshot.plan_version == 1
    assert snapshot.proof_boundary == :future_mobile_ble_lifecycle
    assert snapshot.open_gate_count == 5
    assert snapshot.platform_blocked_count == 1
    refute snapshot.background_claims_allowed?
    refute snapshot.restart_claims_allowed?

    assert :android_foreground_service in ids
    assert :android_background_ble_policy in ids
    assert :ios_background_ble_policy in ids
    assert :automatic_restart in ids
    assert :background_gossip_limits in ids
  end

  test "android foreground service gate requires manifest, notification, and hardware evidence" do
    assert {:ok, gate} = LocalLifecycleProofPlan.get(:android_foreground_service)

    assert gate.status == :planned
    assert :android_manifest_service_declaration in gate.implementation_gates
    assert :foreground_service_permission in gate.implementation_gates
    assert :notification_policy in gate.implementation_gates
    assert :android_foreground_service_ble in gate.blocked_claims

    assert Enum.any?(gate.validation_evidence, &String.contains?(&1, "app backgrounding"))
  end

  test "ios background policy remains platform-blocked until capability and hardware proof exist" do
    assert {:ok, gate} = LocalLifecycleProofPlan.get(:ios_background_ble_policy)

    assert gate.status == :platform_blocked
    assert :ios_background_capability_selection in gate.implementation_gates
    assert :core_bluetooth_background_policy in gate.implementation_gates
    assert :replay_normalized_hardware_capture in gate.implementation_gates
    assert :ios_background_scan in gate.blocked_claims
    assert :ios_background_advertise in gate.blocked_claims
  end

  test "automatic restart gate blocks invisible restart and retry-backed delivery claims" do
    assert {:ok, gate} = LocalLifecycleProofPlan.get(:automatic_restart)

    assert :restart_trigger_policy in gate.implementation_gates
    assert :cancellation_policy in gate.implementation_gates
    assert :operator_visible_restart_status in gate.implementation_gates
    assert :automatic_ble_restart in gate.blocked_claims
    assert :operator_invisible_restart in gate.blocked_claims

    assert Enum.any?(gate.validation_evidence, &String.contains?(&1, "retry-backed delivery"))
  end

  test "background gossip gate requires bounds without delivery claims" do
    assert {:ok, gate} = LocalLifecycleProofPlan.get(:background_gossip_limits)

    assert :background_gossip_rate_limits in gate.implementation_gates
    assert :ttl_and_loop_policy in gate.implementation_gates
    assert :hardware_validation_without_delivery_claims in gate.implementation_gates
    assert :background_gossip in gate.blocked_claims
    assert :background_delivery in gate.blocked_claims
  end

  test "json snapshot is machine readable" do
    snapshot = LocalLifecycleProofPlan.json_snapshot()

    assert snapshot["plan_version"] == 1
    assert snapshot["open_gate_count"] == 5
    assert snapshot["platform_blocked_count"] == 1
    assert snapshot["background_claims_allowed?"] == false
    assert snapshot["restart_claims_allowed?"] == false
    assert Enum.any?(snapshot["gates"], &(&1["requirement_id"] == "automatic_restart"))
  end
end
