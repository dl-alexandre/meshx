defmodule Mob.Node.BLE.LocalFocusedRemainingItemsAuditTest do
  use ExUnit.Case, async: true

  alias Mob.Node.BLE.LocalFocusedRemainingItemsAudit

  test "snapshot preserves focused four-row objective and completion decision" do
    audit = LocalFocusedRemainingItemsAudit.snapshot()

    assert audit.audit == :updated_remaining_items
    assert audit.complete == false
    assert audit.completion_decision.update_goal_allowed == false

    assert audit.completed_rows == [
             :hardware_validation_of_full_ios_responder_path,
             :test_startup_friction_no_start_workaround,
             :upstreaming_mob_dev_mob_patches
           ]

    assert audit.incomplete_rows == [
             :extended_advertising_interop_aux_scan_response
           ]

    assert Enum.map(audit.rows, & &1.id) == [
             :hardware_validation_of_full_ios_responder_path,
             :extended_advertising_interop_aux_scan_response,
             :upstreaming_mob_dev_mob_patches,
             :test_startup_friction_no_start_workaround
           ]

    assert length(audit.objective_success_criteria) == 4
  end

  test "blocked rows keep concrete unblock evidence requirements" do
    rows = LocalFocusedRemainingItemsAudit.snapshot().rows |> Map.new(&{&1.id, &1})
    aux = rows.extended_advertising_interop_aux_scan_response

    assert aux.completion_claim_allowed == false
    assert aux.observed_state.ios_received_message_lines == 0
    assert aux.observed_state.ios_mx_aux_callback_lines == 0
    assert aux.observed_state.alternate_ios_receiver_available == false
    assert Enum.any?(aux.success_criteria, &String.contains?(&1, "FF FF 4D 58"))

    # upstreaming_mob_dev_mob_patches is now complete (moved to completed_rows);
    # its completion_claim_allowed == true and observed_state reflect post-migration reality.
    # See the dedicated completed-row assertions / docs for details.
  end

  test "prompt-to-artifact checklist maps objective rows to commands, tests, and evidence" do
    audit = LocalFocusedRemainingItemsAudit.snapshot()
    checklist = audit.prompt_to_artifact_checklist

    assert Enum.map(checklist, & &1.id) == [
             :objective_scope,
             :full_ios_responder_path,
             :extended_advertising_interop,
             :upstream_mob_patch_migration,
             :test_startup_friction,
             :completion_decision
           ]

    covered_rows =
      checklist
      |> Enum.flat_map(& &1.row_ids)
      |> MapSet.new()

    assert covered_rows ==
             MapSet.new([
               :hardware_validation_of_full_ios_responder_path,
               :extended_advertising_interop_aux_scan_response,
               :upstreaming_mob_dev_mob_patches,
               :test_startup_friction_no_start_workaround
             ])

    assert Enum.all?(checklist, &(&1.evidence_paths != []))
    assert Enum.all?(checklist, &(&1.commands != []))
    assert Enum.all?(checklist, &(&1.tests != []))

    completion = Enum.find(checklist, &(&1.id == :completion_decision))
    assert completion.status == :blocked
    assert completion.gap =~ "extended_advertising_interop_aux_scan_response"
    # upstream row no longer in the gap (now complete)
  end

  test "json snapshot is machine readable" do
    audit = LocalFocusedRemainingItemsAudit.json_snapshot()

    assert audit["complete"] == false
    assert audit["completion_decision"]["update_goal_allowed"] == false
    assert length(audit["completed_rows"]) == 3
    assert length(audit["incomplete_rows"]) == 1
    assert Enum.any?(audit["rows"], &(&1["id"] == "upstreaming_mob_dev_mob_patches"))
    assert length(audit["objective_success_criteria"]) == 4

    assert Enum.any?(
             audit["prompt_to_artifact_checklist"],
             &(&1["id"] == "completion_decision" and &1["status"] == "blocked")
           )
  end
end
