defmodule Mix.Tasks.MeshxMobileLocalReleaseRecentEvidenceTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mix.Tasks.Meshx.Mobile.LocalRelease.RecentEvidence

  setup do
    Mix.Task.reenable("meshx.mobile.local_release.recent_evidence")
    File.rm_rf!("tmp/local-release-recent-evidence-test")
    :ok
  end

  test "prints concise text output" do
    output =
      capture_io(fn ->
        RecentEvidence.run([])
      end)

    assert output =~ "LOCAL_RELEASE_RECENT_EVIDENCE complete=false items=6"
  end

  test "prints and writes json output" do
    path = "tmp/local-release-recent-evidence-test/recent.json"

    output =
      capture_io(fn ->
        RecentEvidence.run(["--json", "--out", path])
      end)

    assert {:ok, decoded} = JSON.decode(output)
    assert decoded["boundary"] == "local_release_recent_evidence_inventory"
    assert decoded["release_candidate_complete?"] == false
    assert File.exists?(path)
  end

  test "rejects unknown options" do
    assert_raise Mix.Error, ~r/unknown option/, fn ->
      capture_io(fn -> RecentEvidence.run(["--bad"]) end)
    end
  end
end
