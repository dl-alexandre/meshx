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
