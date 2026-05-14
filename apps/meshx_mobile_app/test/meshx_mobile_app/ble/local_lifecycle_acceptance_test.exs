defmodule MeshxMobileApp.BLE.LocalLifecycleAcceptanceTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.{LocalInbox, LocalLifecycleAcceptance}

  test "snapshot records foreground/manual gates and blocks background lifecycle claims" do
    acceptance = LocalLifecycleAcceptance.snapshot()

    assert acceptance.boundary == :current_foreground_manual_lifecycle
    assert acceptance.satisfied_count == 5
    assert acceptance.blocked_count == 6
    refute acceptance.background_claims_allowed?
    refute acceptance.restart_claims_allowed?
    refute acceptance.scheduled_retry_claims_allowed?
    refute acceptance.background_gossip_claims_allowed?

    assert [
             %{id: :foreground_manual_profile, status: :satisfied},
             %{id: :lifecycle_policy, status: :satisfied},
             %{id: :future_lifecycle_contract, status: :satisfied},
             %{id: :lifecycle_hardware_validation_plan, status: :satisfied},
             %{id: :negative_lifecycle_validation, status: :satisfied},
             %{id: :android_foreground_service, status: :blocked},
             %{id: :android_background_ble_policy, status: :blocked},
             %{id: :ios_background_ble_policy, status: :blocked},
             %{id: :automatic_restart, status: :blocked},
             %{id: :background_gossip_limits, status: :blocked},
             %{id: :scheduled_retry, status: :blocked}
           ] = acceptance.gates
  end

  test "blocked lifecycle gates carry concrete missing evidence" do
    acceptance = LocalLifecycleAcceptance.snapshot()

    android_service = Enum.find(acceptance.gates, &(&1.id == :android_foreground_service))
    android_background = Enum.find(acceptance.gates, &(&1.id == :android_background_ble_policy))
    ios_background = Enum.find(acceptance.gates, &(&1.id == :ios_background_ble_policy))
    restart = Enum.find(acceptance.gates, &(&1.id == :automatic_restart))
    gossip = Enum.find(acceptance.gates, &(&1.id == :background_gossip_limits))
    retry = Enum.find(acceptance.gates, &(&1.id == :scheduled_retry))

    assert Enum.any?(android_service.missing, &String.contains?(&1, "foreground service"))
    assert Enum.any?(android_background.missing, &String.contains?(&1, "OS throttling"))
    assert Enum.any?(ios_background.missing, &String.contains?(&1, "iOS capabilities"))
    assert Enum.any?(restart.missing, &String.contains?(&1, "restart triggers"))
    assert Enum.any?(gossip.missing, &String.contains?(&1, "rate limits"))
    assert Enum.any?(retry.missing, &String.contains?(&1, "Retry trigger policy"))

    negative = Enum.find(acceptance.gates, &(&1.id == :negative_lifecycle_validation))
    assert :scheduled_retry in negative.blocked_claims
    assert :retry_backed_delivery in negative.blocked_claims

    assert Enum.any?(
             negative.evidence,
             &String.contains?(&1, "fetch-intent-as-retry")
           )
  end

  test "local inbox snapshot exposes lifecycle acceptance without promoting background mode" do
    snapshot = LocalInbox.new() |> LocalInbox.snapshot()

    assert %{lifecycle_acceptance: acceptance} = snapshot
    assert acceptance.satisfied_count == 5
    assert acceptance.blocked_count == 6
    refute acceptance.background_claims_allowed?
  end

  test "JSON snapshot preserves blocked lifecycle claims" do
    snapshot = LocalLifecycleAcceptance.json_snapshot()

    assert snapshot["boundary"] == "current_foreground_manual_lifecycle"
    assert snapshot["background_claims_allowed?"] == false
    assert snapshot["restart_claims_allowed?"] == false
    assert snapshot["scheduled_retry_claims_allowed?"] == false

    assert Enum.any?(
             snapshot["gates"],
             &(&1["id"] == "android_foreground_service" and &1["status"] == "blocked")
           )
  end
end
