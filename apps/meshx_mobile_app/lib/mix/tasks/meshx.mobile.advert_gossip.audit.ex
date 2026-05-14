defmodule Mix.Tasks.Meshx.Mobile.AdvertGossip.Audit do
  @moduledoc """
  Audits replay-only advert gossip scenario fixtures.

      mix meshx.mobile.advert_gossip.audit path/to/scenario.json
      mix meshx.mobile.advert_gossip.audit path/to/scenarios

  The task exits nonzero if any scenario's expected summary does not
  match the simulator result.
  """

  use Mix.Task

  alias MeshxMobileApp.BLE.AdvertGossipScenario

  @shortdoc "Audit replay-only advert gossip scenario fixtures"

  @impl Mix.Task
  def run([]) do
    Mix.raise("expected a scenario JSON file or directory")
  end

  def run(paths) do
    reports =
      paths
      |> Enum.flat_map(&expand_path/1)
      |> Enum.sort()
      |> Enum.map(&AdvertGossipScenario.run_file!/1)

    Enum.each(reports, &print_report/1)

    unless Enum.all?(reports, & &1.passed) do
      Mix.raise("advert gossip scenario audit failed")
    end
  end

  defp expand_path(path) do
    cond do
      File.dir?(path) -> path |> Path.join("*.json") |> Path.wildcard()
      File.regular?(path) -> [path]
      true -> Mix.raise("scenario path not found: #{path}")
    end
  end

  defp print_report(%AdvertGossipScenario.Report{} = report) do
    status = if report.passed, do: "PASS", else: "FAIL"
    Mix.shell().info("#{status} #{report.scenario} #{inspect(report.summary["delivery_counts"])}")

    Enum.each(report.failures, fn failure ->
      Mix.shell().error("  #{failure}")
    end)
  end
end
