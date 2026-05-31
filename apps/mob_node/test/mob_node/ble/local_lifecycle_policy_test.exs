defmodule Mob.Node.BLE.LocalLifecyclePolicyTest do
  use ExUnit.Case, async: true

  alias Mob.Node.BLE.{LocalInbox, LocalLifecyclePolicy}

  test "foreground manual operation is the only allowed lifecycle claim" do
    assert {:ok, capability} = LocalLifecyclePolicy.get(:foreground_manual_operation)

    assert capability.status == :allowed
    assert capability.required_before_allowed == []
    assert Enum.any?(capability.allowed_claims, &String.contains?(&1, "Foreground scan"))
    assert Enum.any?(capability.blocked_claims, &String.contains?(&1, "background"))
  end

  test "platform background lifecycle claims remain blocked" do
    blocked_ids = Enum.map(LocalLifecyclePolicy.blocked(), & &1.id)

    assert :android_foreground_service in blocked_ids
    assert :android_background_ble in blocked_ids
    assert :ios_background_ble in blocked_ids
    assert :automatic_restart in blocked_ids
    assert :scheduled_retry in blocked_ids
    assert :background_gossip in blocked_ids
  end

  test "snapshot blocks background and restart claims" do
    snapshot = LocalLifecyclePolicy.snapshot()

    assert snapshot.mode == :foreground_manual_ble
    assert snapshot.decision_outcome == :keep_foreground_manual
    assert snapshot.decision_status == :selected_for_current_validated_mode

    assert snapshot.background_lifecycle_reconsideration_gate ==
             :mobile_ble_lifecycle_hardware_validation_plan

    assert snapshot.allowed_count == 1
    assert snapshot.blocked_count == 6
    refute snapshot.background_claims_allowed?
    refute snapshot.foreground_service_claim_allowed?
    refute snapshot.restart_claims_allowed?
    refute snapshot.scheduled_retry_claim_allowed?
    refute snapshot.background_gossip_claim_allowed?

    assert Enum.any?(
             snapshot.notes,
             &String.contains?(&1, "Foreground/manual BLE operation is the only")
           )
  end

  test "local inbox snapshot exposes lifecycle policy" do
    snapshot = LocalInbox.new() |> LocalInbox.snapshot()

    assert snapshot.lifecycle_policy.mode == :foreground_manual_ble
    assert snapshot.lifecycle_policy.blocked_count == 6
    refute snapshot.lifecycle_policy.background_claims_allowed?
  end
end
