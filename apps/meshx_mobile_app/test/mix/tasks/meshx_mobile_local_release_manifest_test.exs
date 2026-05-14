defmodule Mix.Tasks.MeshxMobileLocalReleaseManifestTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mix.Tasks.Meshx.Mobile.LocalRelease.Manifest

  setup do
    Mix.Task.reenable("meshx.mobile.local_release.manifest")
    File.rm_rf!("tmp/local-release-manifest-test")
    :ok
  end

  test "prints a concise manifest summary" do
    output =
      capture_io(fn ->
        Manifest.run([])
      end)

    assert output =~ "LOCAL_RELEASE advertisement_only_local_mesh"
    assert output =~ "releasable_with_limitations=true"
    assert output =~ "whole_project_complete=false"
    assert output =~ "READINESS open 10 blocked 3 partial 7"
    assert output =~ "COMPLETION_REVIEW prompt_checklist 10 hardware_blocked 4 no_new_hardware 6"
    assert output =~ "REVIEW_TEMPLATES covered=10/10 all_listed=true"
    assert output =~ "routing_claims_allowed=false"
  end

  test "prints machine-readable JSON" do
    output =
      capture_io(fn ->
        Manifest.run(["--json"])
      end)

    assert {:ok, decoded} = JSON.decode(output)
    assert decoded["manifest_version"] == 1
    assert decoded["whole_project_complete?"] == false
    assert decoded["completion_audit"]["completion_claim_allowed?"] == false
    assert decoded["full_resolution_evidence"]["real_fetch_transport_validated?"] == false
    assert decoded["ux_evidence"]["production_ux_claim_allowed?"] == false
    assert decoded["ios_parity_evidence"]["ios_parity_claim_allowed?"] == false
    assert decoded["lifecycle_evidence"]["background_ble_claim_allowed?"] == false
    assert decoded["multi_hop_hardware_evidence"]["multi_hop_physical_proof_present?"] == false
    assert decoded["persistence_evidence"]["production_default_persistence_allowed?"] == false
    assert decoded["routing_evidence"]["routed_delivery_claim_allowed?"] == false
    assert decoded["policy_gates"]["ios_parity"]["ios_participation_claims_allowed?"] == false
    assert decoded["security_evidence"]["security_evidence_complete?"] == false
    assert decoded["operator_capture_plan"]["boundary"] == "local_release_operator_capture_plan"
    assert length(decoded["operator_capture_plan"]["capture_sections"]) == 5

    manifest_paths =
      Enum.find(decoded["operator_capture_plan"]["capture_sections"], &(&1["id"] == "manifest_paths"))

    assert "completion_audit_plain_text_path" in manifest_paths["required_entries"]
    assert decoded["artifact_bundle"]["artifact_count"] == 49
    assert decoded["artifact_bundle"]["open_artifact_count"] == 19

    assert decoded["completion_audit"]["review_template_coverage"][
             "all_review_templates_listed?"
           ] == true

    assert decoded["completion_audit"]["review_template_coverage"]["covered_review_count"] == 10
  end

  test "writes machine-readable JSON artifact" do
    path = "tmp/local-release-manifest-test/release.json"

    output =
      capture_io(fn ->
        Manifest.run(["--out", path])
      end)

    assert output =~ "LOCAL_RELEASE advertisement_only_local_mesh"
    assert File.exists?(path)
    assert {:ok, decoded} = path |> File.read!() |> JSON.decode()
    assert decoded["required_artifacts"] |> Enum.any?(&(&1["id"] == "release_manifest"))
    assert decoded["required_artifacts"] |> Enum.any?(&(&1["id"] == "completion_audit_manifest"))

    assert decoded["required_artifacts"]
           |> Enum.any?(&(&1["id"] == "release_operator_capture_plan"))

    assert decoded["required_artifacts"]
           |> Enum.any?(&(&1["id"] == "completion_audit_standalone"))

    assert decoded["required_artifacts"]
           |> Enum.any?(&(&1["id"] == "completion_audit_plain_text_review"))

    assert decoded["required_artifacts"] |> Enum.any?(&(&1["id"] == "completion_blocker_matrix"))
    assert decoded["required_commands"] |> Enum.any?(&(&1 =~ "local_completion.audit"))
    assert "mix meshx.mobile.local_completion.audit --allow-open" in decoded["required_commands"]
    assert decoded["required_commands"] |> Enum.any?(&(&1 =~ "local-completion-audit.txt"))
    assert decoded["required_commands"] |> Enum.any?(&(&1 =~ "local_completion.blocker_matrix"))

    assert decoded["required_artifacts"]
           |> Enum.any?(&(&1["id"] == "full_message_resolution_evidence_manifest"))

    assert decoded["required_artifacts"]
           |> Enum.any?(&(&1["id"] == "full_resolution_transport_evidence_review"))

    assert decoded["required_artifacts"]
           |> Enum.any?(&(&1["id"] == "known_good_transport_evidence_review"))

    assert decoded["required_artifacts"] |> Enum.any?(&(&1["id"] == "ux_evidence_manifest"))
    assert decoded["required_artifacts"] |> Enum.any?(&(&1["id"] == "ux_decision_scenario_plan"))

    assert decoded["required_artifacts"]
           |> Enum.any?(&(&1["id"] == "ios_parity_evidence_manifest"))

    assert decoded["required_artifacts"]
           |> Enum.any?(&(&1["id"] == "ios_parity_decision_scenario_plan"))

    assert decoded["required_artifacts"]
           |> Enum.any?(&(&1["id"] == "ios_parity_hardware_evidence_review"))

    assert decoded["required_artifacts"]
           |> Enum.any?(&(&1["id"] == "security_release_evidence_review"))

    assert decoded["required_artifacts"]
           |> Enum.any?(&(&1["id"] == "lifecycle_evidence_manifest"))

    assert decoded["required_artifacts"]
           |> Enum.any?(&(&1["id"] == "lifecycle_decision_scenario_plan"))

    assert decoded["required_artifacts"]
           |> Enum.any?(&(&1["id"] == "multi_hop_hardware_evidence_manifest"))

    assert decoded["required_artifacts"]
           |> Enum.any?(&(&1["id"] == "multi_hop_hardware_evidence_review"))

    assert decoded["required_artifacts"]
           |> Enum.any?(&(&1["id"] == "persistence_evidence_manifest"))

    assert decoded["required_artifacts"]
           |> Enum.any?(&(&1["id"] == "routing_evidence_manifest"))

    assert decoded["required_artifacts"]
           |> Enum.any?(&(&1["id"] == "routing_decision_scenario_plan"))

    assert decoded["required_artifacts"]
           |> Enum.any?(
             &(&1["id"] == "artifact_bundle_checklist" and
                 &1["command"] =~ "local_release.artifact_bundle")
           )

    assert decoded["required_artifacts"]
           |> Enum.any?(
             &(&1["id"] == "recent_evidence_inventory" and
                 &1["command"] =~ "local_release.recent_evidence")
           )

    assert decoded["required_commands"] |> Enum.any?(&(&1 =~ "local_release.recent_evidence"))

    assert decoded["required_artifacts"]
           |> Enum.any?(
             &(&1["id"] == "release_candidate_evidence_review" and
                 &1["command"] =~ "local_release.candidate_review")
           )

    assert decoded["required_artifacts"] |> Enum.any?(&(&1["id"] == "security_evidence_manifest"))
  end

  test "rejects unknown options and missing output path" do
    assert_raise Mix.Error, ~r/unknown option/, fn ->
      capture_io(fn -> Manifest.run(["--bad"]) end)
    end

    assert_raise Mix.Error, ~r/missing path for --out/, fn ->
      capture_io(fn -> Manifest.run(["--out"]) end)
    end
  end
end
