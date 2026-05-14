defmodule Mix.Tasks.MeshxMobileLocalCompletionBlockerMatrixTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mix.Tasks.Meshx.Mobile.LocalCompletion.BlockerMatrix

  setup do
    Mix.Task.reenable("meshx.mobile.local_completion.blocker_matrix")
    File.rm_rf!("tmp/local-completion-blocker-matrix-test")
    :ok
  end

  test "prints a concise blocker matrix summary" do
    output =
      capture_io(fn ->
        BlockerMatrix.run([])
      end)

    assert output =~ "LOCAL_COMPLETION_BLOCKER_MATRIX whole_project_completion_blocker_matrix"
    assert output =~ "completion_allowed=false"
    assert output =~ "BLOCKERS hardware 4 non_hardware 6"

    assert output =~
             "HARDWARE_BLOCKED objectives=full_message_resolution,known_good_transport_validation,multi_hop_hardware_proof,ios_parity"

    assert output =~
             "NO_NEW_HARDWARE objectives=product_ux,persistence,security_identity,routing,background_mobile_lifecycle,release_hardening"

    assert output =~ "RECOMMENDED_NEXT objective=product_ux"
    assert output =~ "evidence_kind classification"
    assert output =~ "limitation_copy"
    assert output =~ "next_action_copy"
    assert output =~ "blocked_claim_copy"
    assert output =~ "coverage_summary"
  end

  test "prints machine-readable JSON" do
    output =
      capture_io(fn ->
        BlockerMatrix.run(["--json"])
      end)

    assert {:ok, decoded} = JSON.decode(output)
    assert decoded["boundary"] == "whole_project_completion_blocker_matrix"
    assert decoded["completion_claim_allowed?"] == false

    assert decoded["blocked_by_new_hardware"] == [
             "full_message_resolution",
             "known_good_transport_validation",
             "multi_hop_hardware_proof",
             "ios_parity"
           ]

    assert decoded["next_action_summary"]["recommended_now"]["objective_id"] == "product_ux"

    assert decoded["next_action_summary"]["recommended_now"]["next_unblock_action"] =~
             "coverage_summary"

    assert Enum.any?(
             decoded["next_action_summary"]["recommended_now"]["required_evidence"],
             &String.contains?(&1, "limitation_copy")
           )
  end

  test "writes machine-readable JSON artifact" do
    path = "tmp/local-completion-blocker-matrix-test/matrix.json"

    output =
      capture_io(fn ->
        BlockerMatrix.run(["--json", "--out", path])
      end)

    assert {:ok, decoded_output} = JSON.decode(output)
    assert decoded_output["boundary"] == "whole_project_completion_blocker_matrix"
    assert File.exists?(path)
    assert {:ok, decoded_file} = path |> File.read!() |> JSON.decode()
    assert decoded_file["completion_claim_allowed?"] == false
  end

  test "rejects unknown options and missing output path" do
    assert_raise Mix.Error, ~r/unknown option/, fn ->
      capture_io(fn -> BlockerMatrix.run(["--bad"]) end)
    end

    assert_raise Mix.Error, ~r/missing path for --out/, fn ->
      capture_io(fn -> BlockerMatrix.run(["--out"]) end)
    end
  end
end
