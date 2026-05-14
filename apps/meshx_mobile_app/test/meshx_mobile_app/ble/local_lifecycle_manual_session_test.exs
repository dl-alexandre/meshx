defmodule MeshxMobileApp.BLE.LocalLifecycleManualSessionTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.LocalLifecycleManualSession

  test "complete manual sessions prove only foreground manual lifecycle evidence" do
    session = %{
      device_id: "AA:01",
      app_state: :foreground,
      actions: [
        :operator_start_scan,
        :operator_start_advertise,
        :operator_observe_events,
        :operator_stop
      ]
    }

    evidence = LocalLifecycleManualSession.evaluate(session)

    assert evidence.boundary == :foreground_manual_lifecycle_session
    assert evidence.status == :complete_foreground_manual
    assert evidence.device_id == "AA:01"
    assert evidence.app_state == :foreground
    assert evidence.foreground_manual_evidence_complete?
    assert evidence.missing_actions == []
    refute evidence.android_foreground_service_claim_allowed?
    refute evidence.background_ble_claim_allowed?
    refute evidence.restart_claim_allowed?
    refute evidence.scheduled_retry_claim_allowed?
    refute evidence.delivery_claim_allowed?
    assert :background_ble_operation in evidence.blocked_claims
  end

  test "incomplete sessions list missing operator actions" do
    evidence =
      LocalLifecycleManualSession.evaluate(%{
        device_id: "AA:01",
        app_state: "foreground",
        actions: ["operator_start_scan"]
      })

    assert evidence.status == :incomplete_foreground_manual
    refute evidence.foreground_manual_evidence_complete?
    assert :operator_start_advertise in evidence.missing_actions
    assert :operator_observe_events in evidence.missing_actions
    assert :operator_stop in evidence.missing_actions
  end

  test "invalid sessions never allow lifecycle claims" do
    evidence = LocalLifecycleManualSession.evaluate(:bad)

    assert evidence.status == :invalid_session
    refute evidence.foreground_manual_evidence_complete?

    assert evidence.missing_actions == [
             :operator_start_scan,
             :operator_start_advertise,
             :operator_observe_events,
             :operator_stop
           ]

    refute evidence.background_ble_claim_allowed?
  end

  test "snapshot summarizes manual foreground evidence without background promotion" do
    complete = %{
      actions: [
        :operator_start_scan,
        :operator_start_advertise,
        :operator_observe_events,
        :operator_stop
      ]
    }

    snapshot = LocalLifecycleManualSession.snapshot([complete, %{actions: []}])

    assert snapshot.boundary == :foreground_manual_lifecycle_session_snapshot
    assert snapshot.session_count == 2
    assert snapshot.complete_session_count == 1
    refute snapshot.android_foreground_service_claim_allowed?
    refute snapshot.background_ble_claim_allowed?
    refute snapshot.restart_claim_allowed?
    refute snapshot.scheduled_retry_claim_allowed?
    refute snapshot.delivery_claim_allowed?

    json = LocalLifecycleManualSession.json_snapshot([complete])
    assert json["boundary"] == "foreground_manual_lifecycle_session_snapshot"
    assert json["background_ble_claim_allowed?"] == false
  end
end
