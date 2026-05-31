defmodule Mix.Tasks.Mob.Node.Rt01.Analyze do
  @moduledoc """
  Analyze an RT-01 locked-phone direct delivery capture.

  ## Usage

      mix mob.node.rt01.analyze --input artifacts/local-ble/rt-01/logcat.log --unlock-at-ms 1779640000000
      mix mob.node.rt01.analyze artifacts/local-ble/rt-01/logcat.log --locked-from 2026-05-24T12:00:00Z --unlock-at 2026-05-24T12:45:00Z
      mix mob.node.rt01.analyze --input logcat.log --unlock-at-ms 1779640000000 --json --out tmp/rt01-analysis.json

  `--unlock-at-ms` / `--locked-from-ms` accept Unix milliseconds.
  `--unlock-at` / `--locked-from` accept ISO-8601 datetimes.
  """

  use Mix.Task

  alias Mob.Node.BLE.RT01LogAnalyzer

  @shortdoc "Analyzes RT-01 locked-phone direct delivery logs"

  @impl Mix.Task
  def run(argv) do
    {opts, rest} =
      OptionParser.parse!(argv,
        strict: [
          input: :string,
          unlock_at_ms: :string,
          unlock_at: :string,
          locked_from_ms: :string,
          locked_from: :string,
          sustained_after_ms: :string,
          json: :boolean,
          out: :string
        ]
      )

    input = opts[:input] || List.first(rest) || Mix.raise("missing --input <log-file>")

    # RT-01 is strict by default: a pass requires receive evidence sustained at
    # least 60s into the locked window. Override with --sustained-after-ms (0
    # restores the legacy "any in-window evidence" gate).
    sustained_after_ms = opts[:sustained_after_ms] || "60000"

    analysis =
      RT01LogAnalyzer.analyze_file(input,
        locked_from_ms: opts[:locked_from_ms] || opts[:locked_from],
        unlock_at_ms: opts[:unlock_at_ms] || opts[:unlock_at],
        sustained_after_ms: sustained_after_ms
      )

    if opts[:json] do
      write_or_print(json(analysis), opts[:out])
    else
      print_summary(analysis)
    end
  end

  defp print_summary(analysis) do
    Mix.shell().info(
      "RT01_ANALYSIS status=#{analysis.status} run_ids=#{Enum.join(analysis.run_ids, ",")} " <>
        "app_events=#{analysis.app_events} native_events=#{analysis.native_events} " <>
        "malformed=#{analysis.malformed_events} " <>
        "locked_evidence=#{length(analysis.locked_persistence_evidence)}"
    )

    Mix.shell().info(
      "RT01_WINDOW locked_from_ms=#{analysis.locked_from_ms || "unknown"} " <>
        "unlock_at_ms=#{analysis.unlock_at_ms || "missing"}"
    )

    Mix.shell().info(
      "RT01_STRICT sustained_after_ms=#{analysis.sustained_after_ms || "off"} " <>
        "in_window=#{analysis.receive_events_in_window} " <>
        "unique=#{analysis.unique_message_hashes_in_window} " <>
        "first_delta_ms=#{analysis.first_receive_delta_ms || "n/a"} " <>
        "last_delta_ms=#{analysis.last_receive_delta_ms || "n/a"} " <>
        "after_60s=#{analysis.receive_events_after_60s} after_5m=#{analysis.receive_events_after_5m}"
    )

    Mix.shell().info(
      "RT01_COVERAGE covers_window=#{analysis.capture_covers_window? || false} " <>
        "first_event_at_ms=#{analysis.capture_first_event_at_ms || "n/a"} " <>
        "last_event_at_ms=#{analysis.capture_last_event_at_ms || "n/a"}"
    )

    Mix.shell().info(
      "RT01_POST_UNLOCK window_ms=#{analysis.post_unlock_resume_window_ms} " <>
        "receives=#{analysis.post_unlock_receive_events} " <>
        "unique=#{analysis.post_unlock_unique_message_hashes} " <>
        "first_delta_ms=#{analysis.first_post_unlock_receive_delta_ms || "n/a"} " <>
        "last_delta_ms=#{analysis.last_post_unlock_receive_delta_ms || "n/a"}"
    )

    Enum.each(analysis.missing, &Mix.shell().info("RT01_MISSING #{&1}"))

    Enum.each(analysis.locked_persistence_evidence, fn event ->
      Mix.shell().info(
        "RT01_EVIDENCE line=#{event.line} at_unix_ms=#{event.at_unix_ms} " <>
          "phase=#{event.phase} event=#{event.event} run_id=#{event.run_id}"
      )
    end)
  end

  defp write_or_print(json, nil), do: Mix.shell().info(json)

  defp write_or_print(json, path) do
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, json <> "\n")
    Mix.shell().info("wrote #{path}")
  end

  defp json(analysis) do
    analysis
    |> :json.encode()
    |> IO.iodata_to_binary()
  end
end
