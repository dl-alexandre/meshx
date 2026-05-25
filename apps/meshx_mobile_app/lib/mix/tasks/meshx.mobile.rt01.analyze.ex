defmodule Mix.Tasks.Meshx.Mobile.Rt01.Analyze do
  @moduledoc """
  Analyze an RT-01 locked-phone direct delivery capture.

  ## Usage

      mix meshx.mobile.rt01.analyze --input artifacts/local-ble/rt-01/logcat.log --unlock-at-ms 1779640000000
      mix meshx.mobile.rt01.analyze artifacts/local-ble/rt-01/logcat.log --locked-from 2026-05-24T12:00:00Z --unlock-at 2026-05-24T12:45:00Z
      mix meshx.mobile.rt01.analyze --input logcat.log --unlock-at-ms 1779640000000 --json --out tmp/rt01-analysis.json

  `--unlock-at-ms` / `--locked-from-ms` accept Unix milliseconds.
  `--unlock-at` / `--locked-from` accept ISO-8601 datetimes.
  """

  use Mix.Task

  alias MeshxMobileApp.BLE.RT01LogAnalyzer

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
          json: :boolean,
          out: :string
        ]
      )

    input = opts[:input] || List.first(rest) || Mix.raise("missing --input <log-file>")

    analysis =
      RT01LogAnalyzer.analyze_file(input,
        locked_from_ms: opts[:locked_from_ms] || opts[:locked_from],
        unlock_at_ms: opts[:unlock_at_ms] || opts[:unlock_at]
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
