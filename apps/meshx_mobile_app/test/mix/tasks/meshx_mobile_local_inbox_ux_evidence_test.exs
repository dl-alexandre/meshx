defmodule Mix.Tasks.MeshxMobileLocalInboxUxEvidenceTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mix.Tasks.Meshx.Mobile.LocalInbox.UxEvidence

  setup do
    Mix.Task.reenable("meshx.mobile.local_inbox.ux_evidence")
    File.rm_rf!("tmp/local-inbox-ux-evidence-test")
    :ok
  end

  test "prints a concise UX evidence summary" do
    output =
      capture_io(fn ->
        UxEvidence.run([])
      end)

    assert output =~ "LOCAL_INBOX_UX_EVIDENCE production_ux_allowed=false"
    assert output =~ "rows=4"
    assert output =~ "UX_VALIDATION open 5"
    assert output =~ "trusted_delivery_allowed=false"
    assert output =~ "UX_SURFACE filter_summary=\"Showing all nearby observations (4).\""
    assert output =~ "sort_summary=\"Full messages, refs, gossip, then stale\""
    assert output =~ "UX_BLOCKED_CLAIMS row_states=4 routing_allowed=false"
    assert output =~ "UX_DETAIL_EVIDENCE states=4 all_delivery_blocked=true"
    assert output =~ "UX_DECISION selected=keep_pure_surface_evidence_only"
    assert output =~ "UX_COPY_REVIEW"
    assert output =~ "filter/sort summaries"
    assert output =~ "detail next actions"
    assert output =~ "per-state blocked-claim copy"
    assert output =~ "control summaries"
    assert output =~ "limitation_copy"
    assert output =~ "next_action_copy"
    assert output =~ "blocked_claim_copy"
    assert output =~ "UX_CAPTURE_PLAN sections=6"
    assert output =~ "artifacts/local-ble/<run-id>/ux/"
  end

  test "prints machine-readable JSON" do
    output =
      capture_io(fn ->
        UxEvidence.run(["--json"])
      end)

    assert {:ok, decoded} = JSON.decode(output)
    assert decoded["manifest_version"] == 1
    assert decoded["boundary"] == "nearby_messages_ux_evidence_manifest"
    assert decoded["production_ux_claim_allowed?"] == false
    assert decoded["surface"]["row_count"] == 4
    assert decoded["surface"]["filter_summary"] == "Showing all nearby observations (4)."
    assert decoded["surface"]["sort_summary"] == "Full messages, refs, gossip, then stale"
    assert decoded["operator_capture_plan"]["boundary"] == "nearby_messages_operator_capture_plan"

    assert decoded["ux_decision_scenario_plan"]["boundary"] ==
             "nearby_messages_ux_decision_scenario_plan"

    assert length(decoded["operator_capture_plan"]["capture_sections"]) == 6
    assert length(decoded["detail_evidence"]) == 4
    assert Enum.all?(decoded["detail_evidence"], &(&1["delivery_claim_allowed?"] == false))
  end

  test "writes machine-readable JSON artifact" do
    path = "tmp/local-inbox-ux-evidence-test/ux.json"

    output =
      capture_io(fn ->
        UxEvidence.run(["--json", "--out", path])
      end)

    assert {:ok, decoded_output} = JSON.decode(output)
    assert decoded_output["boundary"] == "nearby_messages_ux_evidence_manifest"
    assert File.exists?(path)
    assert {:ok, decoded_file} = path |> File.read!() |> JSON.decode()
    assert decoded_file["required_artifacts"] |> Enum.any?(&(&1["id"] == "ux_evidence_manifest"))
    assert decoded_file["required_commands"] |> Enum.any?(&String.contains?(&1, "ux_evidence"))
  end

  test "rejects unknown options and missing output path" do
    assert_raise Mix.Error, ~r/unknown option/, fn ->
      capture_io(fn -> UxEvidence.run(["--bad"]) end)
    end

    assert_raise Mix.Error, ~r/missing path for --out/, fn ->
      capture_io(fn -> UxEvidence.run(["--out"]) end)
    end
  end
end
