defmodule Mix.Tasks.Meshx.Mobile.LocalRelease.RecentEvidence do
  @moduledoc """
  Emit the recent local release evidence inventory.
  """

  use Mix.Task

  alias MeshxMobileApp.BLE.LocalReleaseRecentEvidenceInventory

  @shortdoc "Emits recent local release evidence inventory"

  @impl Mix.Task
  def run(args) do
    {opts, _argv, invalid} =
      OptionParser.parse(args, strict: [json: :boolean, out: :string])

    if invalid != [] do
      Mix.raise("unknown option for local_release.recent_evidence: #{inspect(invalid)}")
    end

    snapshot = LocalReleaseRecentEvidenceInventory.json_snapshot()

    if path = opts[:out] do
      path
      |> Path.dirname()
      |> File.mkdir_p!()

      File.write!(path, JSON.encode!(snapshot) <> "\n")
    end

    if opts[:json] do
      Mix.shell().info(JSON.encode!(snapshot))
    else
      Mix.shell().info(
        "LOCAL_RELEASE_RECENT_EVIDENCE complete=#{snapshot["release_candidate_complete?"]} items=#{snapshot["item_count"]}"
      )
    end
  end
end
