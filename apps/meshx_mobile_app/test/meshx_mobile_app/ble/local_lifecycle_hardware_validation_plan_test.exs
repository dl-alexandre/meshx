defmodule MeshxMobileApp.BLE.LocalLifecycleHardwareValidationPlanTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.LocalLifecycleHardwareValidationPlan

  test "snapshot records blocked lifecycle hardware validation gates" do
    snapshot = LocalLifecycleHardwareValidationPlan.snapshot()

    assert snapshot.boundary == :mobile_ble_lifecycle_hardware_validation_plan
    assert snapshot.current_validated_mode == :foreground_manual
    refute snapshot.background_claims_allowed?
    refute snapshot.restart_claims_allowed?
    refute snapshot.scheduled_retry_claims_allowed?
    refute snapshot.background_gossip_claims_allowed?
    assert snapshot.gate_count == 8
    assert snapshot.blocked_gate_count == 8

    assert [
             %{id: :target_device_matrix, status: :blocked},
             %{id: :android_foreground_service_backgrounding, status: :blocked},
             %{id: :android_background_ble_policy, status: :blocked},
             %{id: :ios_background_ble_policy, status: :blocked},
             %{id: :restart_and_cancellation, status: :blocked},
             %{id: :scheduled_retry_bounds, status: :blocked},
             %{id: :background_gossip_limits, status: :blocked},
             %{id: :negative_claim_review, status: :blocked}
           ] = snapshot.gates
  end

  test "background and restart gates require device logs and policy evidence" do
    snapshot = LocalLifecycleHardwareValidationPlan.snapshot()

    assert gate(snapshot, :android_foreground_service_backgrounding).missing_evidence
           |> Enum.any?(&String.contains?(&1, "app backgrounding"))

    assert gate(snapshot, :android_background_ble_policy).missing_evidence
           |> Enum.any?(&String.contains?(&1, "background and idle"))

    assert gate(snapshot, :ios_background_ble_policy).missing_evidence
           |> Enum.any?(&String.contains?(&1, "iOS hardware logs"))

    assert gate(snapshot, :restart_and_cancellation).missing_evidence
           |> Enum.any?(&String.contains?(&1, "Cancellation"))

    assert gate(snapshot, :scheduled_retry_bounds).missing_evidence
           |> Enum.any?(&String.contains?(&1, "exhausted retry"))
  end

  test "JSON snapshot preserves blocked lifecycle claims" do
    snapshot = LocalLifecycleHardwareValidationPlan.json_snapshot()

    assert snapshot["boundary"] == "mobile_ble_lifecycle_hardware_validation_plan"
    assert snapshot["background_claims_allowed?"] == false
    assert snapshot["restart_claims_allowed?"] == false

    assert Enum.any?(
             snapshot["gates"],
             &(&1["id"] == "background_gossip_limits" and &1["status"] == "blocked")
           )
  end

  defp gate(snapshot, id), do: Enum.find(snapshot.gates, &(&1.id == id))
end
