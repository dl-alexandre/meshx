defmodule Mix.Tasks.Mob.NodeRt01AnalyzeTest do
  use ExUnit.Case

  setup do
    Mix.shell(Mix.Shell.Process)

    on_exit(fn ->
      Mix.shell(Mix.Shell.IO)
      Mix.Task.clear()
    end)
  end

  test "prints RT-01 pass summary for locked evidence" do
    path = tmp_log!([app_event("store", "local_inbox_snapshot_saved", 3_000)])

    Mix.Task.rerun("mob.node.rt01.analyze", [
      "--input",
      path,
      "--locked-from-ms",
      "1000",
      "--unlock-at-ms",
      "5000",
      "--sustained-after-ms",
      "0"
    ])

    assert_receive {:mix_shell, :info,
                    [
                      "RT01_ANALYSIS status=pass run_ids=rt-01-direct-baseline-001 " <>
                        rest
                    ]}

    assert rest =~ "locked_evidence=1"
    assert_receive {:mix_shell, :info, ["RT01_WINDOW locked_from_ms=1000 unlock_at_ms=5000"]}
    assert_receive {:mix_shell, :info, ["RT01_EVIDENCE " <> evidence]}
    assert evidence =~ "event=local_inbox_snapshot_saved"
  end

  test "writes JSON analysis when requested" do
    log_path = tmp_log!([app_event("receive", "mesh_message_received", 3_000)])

    out_path =
      Path.join(System.tmp_dir!(), "rt01-analysis-#{System.unique_integer([:positive])}.json")

    on_exit(fn -> File.rm(out_path) end)

    Mix.Task.rerun("mob.node.rt01.analyze", [
      "--input",
      log_path,
      "--unlock-at-ms",
      "5000",
      "--json",
      "--out",
      out_path
    ])

    assert_receive {:mix_shell, :info, [line]}
    assert line == "wrote #{out_path}"

    decoded = out_path |> File.read!() |> :json.decode()
    assert decoded["status"] == "pass"
    assert decoded["app_events"] == 1
  end

  defp tmp_log!(lines) do
    path = Path.join(System.tmp_dir!(), "rt01-log-#{System.unique_integer([:positive])}.log")
    File.write!(path, Enum.join(lines, "\n") <> "\n")
    path
  end

  defp app_event(phase, event, at_unix_ms) do
    payload =
      %{
        "schema" => "mob_rt_event.v1",
        "run_id" => "rt-01-direct-baseline-001",
        "at_unix_ms" => at_unix_ms,
        "at_monotonic_ms" => at_unix_ms,
        "source" => "probe",
        "phase" => phase,
        "event" => event,
        "metadata" => %{}
      }
      |> :json.encode()
      |> IO.iodata_to_binary()

    "05-24 I Elixir: MobAppEvent: #{payload}"
  end
end
