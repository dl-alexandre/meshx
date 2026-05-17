defmodule Mix.Tasks.MeshxMobileLocalReleaseArtifactBundleTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mix.Tasks.Meshx.Mobile.LocalRelease.ArtifactBundle

  setup do
    Mix.Task.reenable("meshx.mobile.local_release.artifact_bundle")
    File.rm_rf!("tmp/local-release-artifact-bundle-test")
    :ok
  end

  test "prints a concise artifact bundle summary" do
    output =
      capture_io(fn ->
        ArtifactBundle.run([])
      end)

    assert output =~ "LOCAL_RELEASE_ARTIFACT_BUNDLE advert_only_local_release_candidate_bundle"
    assert output =~ "complete=false"
    assert output =~ "ARTIFACTS total 54 open 19"
  end

  test "prints machine-readable JSON" do
    output =
      capture_io(fn ->
        ArtifactBundle.run(["--json"])
      end)

    assert {:ok, decoded} = JSON.decode(output)
    assert decoded["bundle_version"] == 1
    assert decoded["boundary"] == "advert_only_local_release_candidate_bundle"
    assert decoded["release_candidate_complete?"] == false
    assert decoded["artifact_count"] == 54
    assert decoded["open_artifact_count"] == 19
  end

  test "writes machine-readable JSON artifact" do
    path = "tmp/local-release-artifact-bundle-test/bundle.json"

    output =
      capture_io(fn ->
        ArtifactBundle.run(["--json", "--out", path])
      end)

    assert {:ok, decoded_output} = JSON.decode(output)
    assert decoded_output["boundary"] == "advert_only_local_release_candidate_bundle"
    assert File.exists?(path)
    assert {:ok, decoded_file} = path |> File.read!() |> JSON.decode()

    assert decoded_file["artifacts"]
           |> Enum.any?(&(&1["id"] == "hardware_log_bundle"))

    assert decoded_file["artifacts"]
           |> Enum.any?(&(&1["id"] == "full_resolution_transport_evidence_review"))

    assert decoded_file["artifacts"]
           |> Enum.any?(&(&1["id"] == "known_good_transport_evidence_review"))

    assert decoded_file["artifacts"]
           |> Enum.any?(&(&1["id"] == "completion_audit_plain_text_review"))

    assert decoded_file["artifacts"]
           |> Enum.any?(&(&1["id"] == "completion_blocker_matrix"))

    assert decoded_file["artifacts"]
           |> Enum.any?(&(&1["id"] == "completion_audit_standalone"))

    assert decoded_file["artifacts"]
           |> Enum.any?(&(&1["id"] == "focused_remaining_items_audit"))

    assert decoded_file["artifacts"]
           |> Enum.any?(&(&1["id"] == "focused_remaining_items_plain_text_review"))

    assert decoded_file["artifacts"]
           |> Enum.any?(&(&1["id"] == "release_operator_capture_plan"))

    assert decoded_file["artifacts"]
           |> Enum.any?(&(&1["id"] == "multi_hop_hardware_evidence_review"))

    assert decoded_file["artifacts"]
           |> Enum.any?(&(&1["id"] == "ux_evidence_template"))

    assert decoded_file["artifacts"]
           |> Enum.any?(&(&1["id"] == "ios_parity_hardware_evidence_review"))

    assert decoded_file["artifacts"]
           |> Enum.any?(&(&1["id"] == "ios_parity_operator_capture_plan"))

    assert decoded_file["artifacts"]
           |> Enum.any?(&(&1["id"] == "ios_parity_decision_scenario_plan"))

    assert decoded_file["artifacts"]
           |> Enum.any?(&(&1["id"] == "security_release_evidence_review"))

    assert decoded_file["artifacts"]
           |> Enum.any?(&(&1["id"] == "security_decision_scenario_plan"))

    assert decoded_file["artifacts"]
           |> Enum.any?(&(&1["id"] == "lifecycle_decision_scenario_plan"))

    assert decoded_file["artifacts"]
           |> Enum.any?(&(&1["id"] == "routing_decision_scenario_plan"))

    assert decoded_file["artifacts"]
           |> Enum.any?(&(&1["id"] == "security_operator_capture_plan"))

    assert decoded_file["artifacts"]
           |> Enum.any?(&(&1["id"] == "operator_release_notes"))

    assert decoded_file["required_commands"]
           |> Enum.any?(&String.contains?(&1, "local_release.manifest"))

    assert decoded_file["required_commands"]
           |> Enum.any?(&String.contains?(&1, "local_completion.audit"))

    assert decoded_file["required_commands"]
           |> Enum.any?(
             &String.contains?(&1, "mix meshx.mobile.local_completion.audit --allow-open")
           )

    assert decoded_file["required_commands"]
           |> Enum.any?(&String.contains?(&1, "local_completion.blocker_matrix"))

    assert decoded_file["required_commands"]
           |> Enum.any?(&String.contains?(&1, "local_full_resolution.transport_review"))

    assert decoded_file["required_commands"]
           |> Enum.any?(&String.contains?(&1, "local_multi_hop_hardware.review"))

    assert decoded_file["required_commands"]
           |> Enum.any?(&String.contains?(&1, "local_inbox.ux_review --template"))

    assert decoded_file["required_commands"]
           |> Enum.any?(&String.contains?(&1, "local_security.release_review"))
  end

  test "rejects unknown options and missing output path" do
    assert_raise Mix.Error, ~r/unknown option/, fn ->
      capture_io(fn -> ArtifactBundle.run(["--bad"]) end)
    end

    assert_raise Mix.Error, ~r/missing path for --out/, fn ->
      capture_io(fn -> ArtifactBundle.run(["--out"]) end)
    end
  end
end
