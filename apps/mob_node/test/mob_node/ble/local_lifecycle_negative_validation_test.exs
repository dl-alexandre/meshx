defmodule Mob.Node.BLE.LocalLifecycleNegativeValidationTest do
  use ExUnit.Case, async: true

  alias Mob.Node.BLE.LocalLifecycleNegativeValidation

  test "snapshot blocks background, restart, and scheduled retry claims" do
    snapshot = LocalLifecycleNegativeValidation.snapshot()

    assert snapshot.validation_version == 1
    assert snapshot.boundary == :current_foreground_manual_lifecycle
    assert snapshot.case_count == 6
    refute snapshot.background_claims_allowed?
    refute snapshot.restart_claims_allowed?
    refute snapshot.scheduled_retry_claims_allowed?
  end

  test "manual foreground operation cannot be claimed as background service" do
    snapshot = LocalLifecycleNegativeValidation.snapshot()
    validation = Enum.find(snapshot.cases, &(&1.id == :manual_foreground_scan_as_background))

    assert validation.input == :foreground_manual_scan_or_advertise
    assert validation.expected_decision == :foreground_only
    assert :android_foreground_service_ble in validation.blocked_claims
    assert :hardware_backgrounding_evidence in validation.required_before_allowed
  end

  test "iOS bridge shell remains platform blocked for background BLE" do
    snapshot = LocalLifecycleNegativeValidation.snapshot()
    validation = Enum.find(snapshot.cases, &(&1.id == :ios_bridge_shell_as_background))

    assert validation.expected_decision == :platform_blocked
    assert :ios_background_scan in validation.blocked_claims
    assert :core_bluetooth_background_policy in validation.required_before_allowed
    assert :replay_normalized_hardware_capture in validation.required_before_allowed
  end

  test "manual restart and foreground gossip do not prove automatic/background behavior" do
    snapshot = LocalLifecycleNegativeValidation.snapshot()
    restart = Enum.find(snapshot.cases, &(&1.id == :manual_restart_as_automatic_restart))
    gossip = Enum.find(snapshot.cases, &(&1.id == :foreground_gossip_as_background_gossip))

    assert restart.expected_decision == :manual_only
    assert gossip.expected_decision == :foreground_gossip_only
    assert :automatic_ble_restart in restart.blocked_claims
    assert :background_gossip in gossip.blocked_claims
    assert :restart_trigger_policy in restart.required_before_allowed
    assert :battery_budget in gossip.required_before_allowed
  end

  test "fetch request intents do not prove scheduled retry or delivery" do
    snapshot = LocalLifecycleNegativeValidation.snapshot()

    validation =
      Enum.find(snapshot.cases, &(&1.id == :fetch_request_intent_as_scheduled_retry))

    assert validation.input == :beacon_fetch_request_or_failed_transport_intent
    assert validation.expected_decision == :fetch_intent_only
    assert :scheduled_retry in validation.blocked_claims
    assert :retry_backed_delivery in validation.blocked_claims
    assert :background_delivery in validation.blocked_claims
    assert :scheduled_work_policy in validation.required_before_allowed
    assert :hardware_lifecycle_logs in validation.required_before_allowed
  end

  test "json snapshot is machine readable" do
    snapshot = LocalLifecycleNegativeValidation.json_snapshot()

    assert snapshot["validation_version"] == 1
    assert snapshot["background_claims_allowed?"] == false

    assert Enum.any?(
             snapshot["cases"],
             &(&1["id"] == "android_background_without_os_evidence" and
                 &1["expected_decision"] == "background_claim_rejected")
           )

    assert Enum.any?(
             snapshot["cases"],
             &(&1["id"] == "fetch_request_intent_as_scheduled_retry" and
                 &1["expected_decision"] == "fetch_intent_only")
           )
  end
end
