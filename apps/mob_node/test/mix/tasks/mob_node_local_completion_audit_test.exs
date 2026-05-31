defmodule Mix.Tasks.Mob.NodeLocalCompletionAuditTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mix.Tasks.Mob.Node.LocalCompletion.Audit

  setup do
    Mix.Task.reenable("mob.node.local_completion.audit")
    File.rm_rf!("tmp/local-completion-audit-test")
    :ok
  end

  test "prints a concise completion audit summary when open items are allowed" do
    output =
      capture_io(fn ->
        Audit.run(["--allow-open"])
      end)

    assert output =~ "LOCAL_COMPLETION_AUDIT whole_project_completion completion_allowed=false"
    assert output =~ "OPEN 10 blocked 3 partial 7 not_started 0"

    assert output =~
             "PROMPT_CHECKLIST 10 objectives=full_message_resolution,known_good_transport_validation,multi_hop_hardware_proof,product_ux,persistence,security_identity,routing,background_mobile_lifecycle,ios_parity,release_hardening"

    assert output =~ "OPEN_ITEMS 10"
    assert output =~ "OPEN_ITEM objective=full_message_resolution status=blocked missing="
    assert output =~ "OPEN_ITEM objective=known_good_transport_validation status=blocked missing="
    assert output =~ "OPEN_ITEM objective=multi_hop_hardware_proof status=blocked missing="
    assert output =~ "OPEN_ITEM objective=product_ux status=partial missing="
    assert output =~ "OPEN_ITEM objective=persistence status=partial missing="
    assert output =~ "OPEN_ITEM objective=security_identity status=partial missing="
    assert output =~ "OPEN_ITEM objective=routing status=partial missing="
    assert output =~ "OPEN_ITEM objective=background_mobile_lifecycle status=partial missing="
    assert output =~ "OPEN_ITEM objective=ios_parity status=partial missing="
    assert output =~ "OPEN_ITEM objective=release_hardening status=partial missing="

    assert output =~
             "HARDWARE_BLOCKED 4 objectives=full_message_resolution,known_good_transport_validation,multi_hop_hardware_proof,ios_parity"

    assert output =~
             "NO_NEW_HARDWARE 6 objectives=product_ux,persistence,security_identity,routing,background_mobile_lifecycle,release_hardening"

    assert output =~ "RECOMMENDED_NEXT objective=product_ux action="
    assert output =~ "target-device UX evidence"
    assert output =~ "evidence_kind"
    assert output =~ "limitation_copy"
    assert output =~ "next_action_copy"
    assert output =~ "blocked_claim_copy"
    assert output =~ "coverage_summary"

    assert output =~ "REVIEW_TEMPLATES covered=10/10 all_listed=true"
  end

  test "prints machine-readable JSON when open items are allowed" do
    output =
      capture_io(fn ->
        Audit.run(["--allow-open", "--json"])
      end)

    assert {:ok, decoded} = JSON.decode(output)
    assert decoded["objective"] == "whole_project_completion"
    assert decoded["completion_claim_allowed?"] == false
    assert decoded["open_item_count"] == 10
    assert length(decoded["prompt_artifact_checklist"]) == 10
    assert decoded["review_template_coverage"]["all_review_templates_listed?"] == true
    assert decoded["review_template_coverage"]["covered_review_count"] == 10

    assert decoded["required_commands"]
           |> Enum.any?(&String.contains?(&1, "local_full_resolution.evidence"))

    assert "mix mob.node.local_completion.audit --allow-open" in decoded[
             "required_commands"
           ]

    assert decoded["required_commands"]
           |> Enum.any?(&String.contains?(&1, "local-completion-audit.txt"))
  end

  test "writes machine-readable JSON artifact" do
    path = "tmp/local-completion-audit-test/audit.json"

    output =
      capture_io(fn ->
        Audit.run(["--allow-open", "--json", "--out", path])
      end)

    assert {:ok, decoded_output} = JSON.decode(output)
    assert decoded_output["completion_claim_allowed?"] == false
    assert File.exists?(path)
    assert {:ok, decoded_file} = path |> File.read!() |> JSON.decode()
    assert decoded_file["blocker_matrix"]["boundary"] == "whole_project_completion_blocker_matrix"
  end

  test "fails by default while completion remains blocked" do
    assert_raise Mix.Error, ~r/whole-project completion remains blocked/, fn ->
      capture_io(fn -> Audit.run([]) end)
    end
  end

  test "rejects unknown options and missing output path" do
    assert_raise Mix.Error, ~r/unknown option/, fn ->
      capture_io(fn -> Audit.run(["--bad"]) end)
    end

    assert_raise Mix.Error, ~r/missing path for --out/, fn ->
      capture_io(fn -> Audit.run(["--out"]) end)
    end
  end
end
