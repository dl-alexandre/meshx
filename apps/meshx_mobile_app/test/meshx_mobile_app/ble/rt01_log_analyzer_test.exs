defmodule MeshxMobileApp.BLE.RT01LogAnalyzerTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.RT01LogAnalyzer

  test "passes when receive or persistence evidence occurs before unlock" do
    lines = [
      app_event("receive", "mesh_message_received", 3_000, %{"message_id" => "m1"}),
      app_event("receive", "mesh_message_received", 6_000, %{"message_id" => "m2"})
    ]

    analysis = RT01LogAnalyzer.analyze_lines(lines, locked_from_ms: 1_000, unlock_at_ms: 5_000)

    assert analysis.status == :pass
    assert analysis.app_events == 2
    assert [evidence] = analysis.locked_persistence_evidence
    assert evidence.at_unix_ms == 3_000
    assert evidence.event == "mesh_message_received"
  end

  test "strict gate passes when receive evidence is sustained into the locked window" do
    lines = [
      app_event("app", "mob_app_start", 500, %{}),
      app_event("receive", "mesh_message_received", 2_000, %{"message_id" => "m1"}),
      app_event("receive", "mesh_message_received", 121_000, %{"message_id" => "m2"}),
      app_event("wake", "selftest_heartbeat", 1_801_000, %{})
    ]

    analysis =
      RT01LogAnalyzer.analyze_lines(lines,
        locked_from_ms: 1_000,
        unlock_at_ms: 1_800_000,
        sustained_after_ms: 60_000
      )

    assert analysis.status == :pass
    assert analysis.receive_events_in_window == 2
    assert analysis.receive_events_after_60s == 1
    assert analysis.sustained_after_ms == 60_000
    assert analysis.capture_covers_window?
  end

  test "strict gate fails on an opening burst that then goes silent (background scan freeze)" do
    # Mirrors the rt-01-direct-baseline-001 signature: one message delivered in
    # a ~1s burst right after screen-off, then no receive callbacks for the rest
    # of the locked window.
    lines = [
      app_event("app", "mob_app_start", 500, %{}),
      app_event("receive", "mesh_message_beacon_received", 1_863, %{"message_id_hash" => "8b8dc8"}),
      app_event("receive", "mesh_message_beacon_received", 2_787, %{"message_id_hash" => "8b8dc8"}),
      app_event("wake", "selftest_heartbeat", 1_801_000, %{})
    ]

    analysis =
      RT01LogAnalyzer.analyze_lines(lines,
        locked_from_ms: 1_000,
        unlock_at_ms: 1_800_000,
        sustained_after_ms: 60_000
      )

    assert analysis.status == :fail
    assert analysis.receive_events_in_window == 2
    assert analysis.unique_message_hashes_in_window == 1
    assert analysis.receive_events_after_60s == 0
    assert analysis.first_receive_delta_ms == 863
    assert analysis.last_receive_delta_ms == 1_787
    assert analysis.capture_covers_window?
  end

  test "strict gate is inconclusive when capture does not bracket the lock window" do
    lines = [
      # Simulates the partial T390 capture: receive evidence exists well after
      # lock start, but the log begins late and cannot prove what happened at
      # the actual transition into screen-off.
      app_event("receive", "mesh_message_beacon_received", 287_000, %{
        "message_id_hash" => "burst"
      }),
      app_event("receive", "mesh_message_beacon_received", 321_000, %{
        "message_id_hash" => "burst"
      })
    ]

    analysis =
      RT01LogAnalyzer.analyze_lines(lines,
        locked_from_ms: 1_000,
        unlock_at_ms: 1_800_000,
        sustained_after_ms: 60_000
      )

    assert analysis.status == :inconclusive
    refute analysis.capture_covers_window?
    assert "capture_coverage" in analysis.missing
    assert analysis.receive_events_after_60s == 2
  end

  test "surfaces post-unlock receive resume as corroborating evidence" do
    lines = [
      app_event("app", "mob_app_start", 500, %{}),
      app_event("receive", "mesh_message_beacon_received", 1_863, %{"message_id_hash" => "pre"}),
      app_event("wake", "selftest_heartbeat", 1_800_000, %{}),
      app_event("receive", "mesh_message_beacon_received", 1_801_200, %{
        "message_id_hash" => "post-1"
      }),
      app_event("receive", "mesh_message_beacon_received", 1_805_000, %{
        "message_id_hash" => "post-2"
      })
    ]

    analysis =
      RT01LogAnalyzer.analyze_lines(lines,
        locked_from_ms: 1_000,
        unlock_at_ms: 1_800_000,
        sustained_after_ms: 60_000
      )

    assert analysis.status == :fail
    assert analysis.post_unlock_receive_events == 2
    assert analysis.post_unlock_unique_message_hashes == 2
    assert analysis.first_post_unlock_receive_delta_ms == 1_200
    assert analysis.last_post_unlock_receive_delta_ms == 5_000
  end

  test "fails when unlock time is known but evidence arrives only after unlock" do
    lines = [
      app_event("receive", "mesh_message_received", 6_000, %{"message_id" => "late"})
    ]

    analysis = RT01LogAnalyzer.analyze_lines(lines, locked_from_ms: 1_000, unlock_at_ms: 5_000)

    assert analysis.status == :fail
    assert analysis.locked_persistence_evidence == []
    assert analysis.missing == []
  end

  test "is inconclusive without operator unlock timestamp" do
    lines = [
      app_event("store", "local_inbox_snapshot_saved", 3_000, %{"full_messages" => 1})
    ]

    analysis = RT01LogAnalyzer.analyze_lines(lines)

    assert analysis.status == :inconclusive
    assert "unlock_at_ms" in analysis.missing
  end

  test "is inconclusive when app events exist but no receive or store evidence is present" do
    lines = [
      app_event("app", "mob_app_start", 2_000, %{"platform" => "android"})
    ]

    analysis = RT01LogAnalyzer.analyze_lines(lines, locked_from_ms: 1_000, unlock_at_ms: 5_000)

    assert analysis.status == :inconclusive
    assert analysis.missing == []
    assert analysis.locked_persistence_evidence == []
  end

  test "counts native and malformed capture events separately" do
    lines = [
      ~s(05-24 I MeshxBle: {"v":1,"event":"device_discovered"}),
      "05-24 I Elixir: MeshxAppEvent: not-json"
    ]

    analysis = RT01LogAnalyzer.analyze_lines(lines, unlock_at_ms: 5_000)

    assert analysis.native_events == 1
    assert analysis.malformed_events == 1
    assert analysis.app_events == 0
    assert analysis.status == :inconclusive
    assert "MeshxAppEvent lines" in analysis.missing
  end

  test "parses ISO-8601 timestamps for operator lock windows" do
    assert 1_779_651_000_000 =
             RT01LogAnalyzer.parse_time_ms("2026-05-24T19:30:00Z")
  end

  test "synthetic fixture statuses match expected RT-01 outcomes" do
    cases = [
      {"pass.logcat", :pass, 2},
      {"fail_after_unlock.logcat", :fail, 0},
      {"inconclusive_no_evidence.logcat", :inconclusive, 0}
    ]

    for {fixture, status, evidence_count} <- cases do
      analysis =
        fixture
        |> fixture_path()
        |> RT01LogAnalyzer.analyze_file(locked_from_ms: 1_000, unlock_at_ms: 5_000)

      assert analysis.status == status
      assert length(analysis.locked_persistence_evidence) == evidence_count
      assert analysis.native_events >= 0
      assert analysis.app_events > 0
    end
  end

  defp app_event(phase, event, at_unix_ms, metadata) do
    payload =
      %{
        "schema" => "meshx_rt_event.v1",
        "run_id" => "rt-01-direct-baseline-001",
        "at_unix_ms" => at_unix_ms,
        "at_monotonic_ms" => at_unix_ms,
        "source" => "ble_event",
        "phase" => phase,
        "event" => event,
        "metadata" => metadata
      }
      |> :json.encode()
      |> IO.iodata_to_binary()

    "05-24 I Elixir: MeshxAppEvent: #{payload}"
  end

  defp fixture_path(name) do
    Path.expand("../../fixtures/rt01/#{name}", __DIR__)
  end
end