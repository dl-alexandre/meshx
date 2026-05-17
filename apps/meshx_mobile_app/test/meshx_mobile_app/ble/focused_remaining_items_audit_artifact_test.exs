defmodule MeshxMobileApp.BLE.FocusedRemainingItemsAuditArtifactTest do
  use ExUnit.Case, async: true

  @audit_path "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/manifests/focused-remaining-items-audit.json"

  test "focused remaining-items artifact preserves exact four-row completion state" do
    audit = read_audit()

    assert audit["audit"] == "updated_remaining_items"
    assert audit["complete"] == false
    assert audit["completion_decision"]["update_goal_allowed"] == false

    assert audit["completed_rows"] == [
             "hardware_validation_of_full_ios_responder_path",
             "test_startup_friction_no_start_workaround"
           ]

    assert audit["incomplete_rows"] == [
             "extended_advertising_interop_aux_scan_response",
             "upstreaming_mob_dev_mob_patches"
           ]

    assert Enum.map(audit["rows"], & &1["id"]) == [
             "hardware_validation_of_full_ios_responder_path",
             "extended_advertising_interop_aux_scan_response",
             "upstreaming_mob_dev_mob_patches",
             "test_startup_friction_no_start_workaround"
           ]
  end

  test "completed rows have source evidence and blocked rows stay unclaimable" do
    rows = read_audit()["rows"] |> Map.new(&{&1["id"], &1})

    responder = rows["hardware_validation_of_full_ios_responder_path"]
    startup = rows["test_startup_friction_no_start_workaround"]
    aux = rows["extended_advertising_interop_aux_scan_response"]
    upstream = rows["upstreaming_mob_dev_mob_patches"]

    assert responder["completion_claim_allowed"] == true

    assert Enum.any?(
             responder["evidence"],
             &String.contains?(&1, "android-fetch-ios-responder-rerun")
           )

    assert Enum.any?(responder["success_criteria"], &String.contains?(&1, "MFQ"))

    assert startup["completion_claim_allowed"] == true
    assert startup["observed_state"]["root_mix_test_without_no_start"] =~ "passed"

    assert aux["completion_claim_allowed"] == false
    assert aux["observed_state"]["ios_received_message_lines"] == 0
    assert aux["observed_state"]["ios_mx_aux_callback_lines"] == 0
    assert aux["observed_state"]["alternate_ios_receiver_available"] == false
    assert Enum.any?(aux["success_criteria"], &String.contains?(&1, "FF FF 4D 58"))

    assert upstream["completion_claim_allowed"] == false
    assert upstream["observed_state"]["mob_dev_pr"]["state"] == "OPEN"
    assert upstream["observed_state"]["mob_new_pr"]["state"] == "OPEN"
    assert upstream["observed_state"]["mob_dev_pr"]["viewer_permission"] == "READ"
    assert upstream["observed_state"]["mob_new_pr"]["viewer_permission"] == "READ"
    assert Enum.any?(upstream["success_criteria"], &String.contains?(&1, "merged and released"))
  end

  test "all focused audit evidence paths resolve to local artifacts" do
    for row <- read_audit()["rows"], evidence <- row["evidence"] do
      path = evidence |> String.split("#", parts: 2) |> hd()

      assert File.exists?(repo_path(path)),
             "missing evidence path for #{row["id"]}: #{evidence}"
    end
  end

  test "prompt-to-artifact checklist covers every objective row and resolves local paths" do
    audit = read_audit()
    checklist = audit["prompt_to_artifact_checklist"]

    assert Enum.map(checklist, & &1["id"]) == [
             "objective_scope",
             "full_ios_responder_path",
             "extended_advertising_interop",
             "upstream_mob_patch_migration",
             "test_startup_friction",
             "completion_decision"
           ]

    covered_rows =
      checklist
      |> Enum.flat_map(& &1["row_ids"])
      |> MapSet.new()

    assert covered_rows == MapSet.new(Enum.map(audit["rows"], & &1["id"]))

    assert Enum.all?(checklist, &(&1["commands"] != []))
    assert Enum.all?(checklist, &(&1["tests"] != []))

    for item <- checklist, path <- item["evidence_paths"] do
      path_without_anchor = path |> String.split("#", parts: 2) |> hd()

      assert File.exists?(repo_path(path_without_anchor)),
             "missing checklist evidence path for #{item["id"]}: #{path}"
    end

    completion = Enum.find(checklist, &(&1["id"] == "completion_decision"))
    assert completion["status"] == "blocked"
    assert completion["gap"] =~ "extended_advertising_interop_aux_scan_response"
    assert audit["completion_decision"]["update_goal_allowed"] == false
  end

  test "blocked rows match fresh external blocker source artifacts" do
    rows = read_audit()["rows"] |> Map.new(&{&1["id"], &1})
    aux = rows["extended_advertising_interop_aux_scan_response"]
    upstream = rows["upstreaming_mob_dev_mob_patches"]

    devices =
      "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/external-blocker-recheck-1358/devicectl-devices.txt"
      |> repo_path()
      |> File.read!()

    assert devices =~ "Coding iPad"
    assert devices =~ "connected"
    assert devices =~ "DairyPhoneDeaux"
    assert devices =~ "unavailable"
    assert aux["observed_state"]["alternate_ios_receiver_available"] == false

    mob_dev_pr =
      read_json(
        "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/upstream-pr-recheck-1358/mob-dev-pr-6.json"
      )

    mob_new_pr =
      read_json(
        "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/upstream-pr-recheck-1358/mob-new-pr-5.json"
      )

    mob_dev_repo =
      read_json(
        "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/upstream-pr-recheck-1358/mob-dev-repo.json"
      )

    mob_new_repo =
      read_json(
        "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/upstream-pr-recheck-1358/mob-new-repo.json"
      )

    assert_upstream_row_matches_raw_artifacts(
      upstream["observed_state"]["mob_dev_pr"],
      mob_dev_pr,
      mob_dev_repo
    )

    assert_upstream_row_matches_raw_artifacts(
      upstream["observed_state"]["mob_new_pr"],
      mob_new_pr,
      mob_new_repo
    )

    handoff =
      "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/upstream-pr-recheck-1358/maintainer-handoff.md"
      |> repo_path()
      |> File.read!()

    migration_progress =
      read_json(
        "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/upstream-pr-recheck-1358/upstream-migration-progress.json"
      )

    assert handoff =~ "GenericJam/mob_dev#6"
    assert handoff =~ "GenericJam/mob_new#5"
    assert handoff =~ "current token has only `READ` permission"
    assert handoff =~ "MeshX Post-Merge Migration Gate"
    assert handoff =~ "mix test"
    assert handoff =~ "upstream-migration-progress.json"

    patch_check =
      "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/manifests/patch-deps-check-1212.log"
      |> repo_path()
      |> File.read!()

    assert upstream["observed_state"]["downstream_patch_check"] =~ "2026-05-17T12:12:03"
    assert Enum.any?(upstream["evidence"], &String.ends_with?(&1, "patch-deps-check-1212.log"))

    assert Enum.any?(
             upstream["evidence"],
             &String.ends_with?(&1, "upstream-migration-progress.json")
           )

    assert patch_check =~ "patches/01-mob_dev-meshx-build-additions.patch: already patched"
    assert patch_check =~ "patches/02-mob-static-nif-table.patch: already patched"

    assert migration_progress["completion_claim_allowed"] == false
    assert migration_progress["row_id"] == "upstreaming_mob_dev_mob_patches"
    assert "downstream_patch_path_verified" in migration_progress["satisfied_criteria"]
    assert "replacement_prs_open" in migration_progress["satisfied_criteria"]
    assert "maintainer_handoff_present" in migration_progress["satisfied_criteria"]
    assert "viewer_permission_recorded" in migration_progress["satisfied_criteria"]
    assert "upstream_prs_merged" in migration_progress["missing_criteria"]
    assert "upstream_changes_released" in migration_progress["missing_criteria"]
    assert "meshx_dependency_migration" in migration_progress["missing_criteria"]
    assert "downstream_patch_removal" in migration_progress["missing_criteria"]
    assert "post_migration_verification" in migration_progress["missing_criteria"]

    migration_criteria = Map.new(migration_progress["criteria"], &{&1["id"], &1})
    assert migration_criteria["replacement_prs_open"]["status"] == "satisfied"
    assert migration_criteria["viewer_permission_recorded"]["status"] == "satisfied"
    assert migration_criteria["upstream_prs_merged"]["status"] == "missing"
    assert migration_criteria["post_migration_verification"]["status"] == "missing"
  end

  test "AUX blocked row matches raw scan-response logs" do
    rows = read_audit()["rows"] |> Map.new(&{&1["id"], &1})
    aux = rows["extended_advertising_interop_aux_scan_response"]

    first_probe =
      read_aux_probe_artifacts(
        "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/android-aux-full-mx-ios-observe"
      )

    rerun =
      read_aux_probe_artifacts(
        "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/android-aux-full-mx-ios-observe-rerun"
      )

    assert_android_started_scan_response(first_probe.android_logcat)
    assert_android_started_scan_response(rerun.android_logcat)

    assert count_log_lines(first_probe.ipad_log, "legacy_beacon_received") == 276
    assert count_log_lines(rerun.ipad_log, "legacy_beacon_received") == 120

    assert_aux_log_has_no_direct_mx_callback(first_probe.ipad_log)
    assert_aux_log_has_no_direct_mx_callback(rerun.ipad_log)

    assert aux["observed_state"]["android_aux_payload_size"] == 80
    assert aux["observed_state"]["android_aux_carrier"] == "scan_response"
    assert aux["observed_state"]["ios_legacy_beacon_lines_first_probe"] == 276
    assert aux["observed_state"]["ios_legacy_beacon_lines_rerun"] == 120
    assert aux["observed_state"]["ios_received_message_lines"] == 0
    assert aux["observed_state"]["ios_decode_error_lines"] == 0
    assert aux["observed_state"]["ios_candidate_discovery_lines"] == 0
    assert aux["observed_state"]["ios_mx_aux_callback_lines"] == 0

    validation_checklist =
      "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/android-aux-full-mx-ios-observe-rerun/aux-validation-checklist.md"
      |> repo_path()
      |> File.read!()

    closure_progress =
      read_json(
        "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/android-aux-full-mx-ios-observe-rerun/aux-closure-progress.json"
      )

    assert validation_checklist =~ "FF FF 4D 58"
    assert validation_checklist =~ "Platform callback proof"
    assert validation_checklist =~ "Canonical parse proof"
    assert validation_checklist =~ "MB beacon fallback still works"
    assert validation_checklist =~ "row remains incomplete"
    assert validation_checklist =~ "aux-closure-progress.json"
    assert validation_checklist =~ "Current closure-progress summary"

    assert closure_progress["completion_claim_allowed"] == false
    assert closure_progress["row_id"] == "extended_advertising_interop_aux_scan_response"
    assert "mb_fallback_control" in closure_progress["satisfied_criteria"]
    assert "negative_boundary_notes" in closure_progress["satisfied_criteria"]
    assert "platform_callback_proof" in closure_progress["missing_criteria"]
    assert "canonical_parse_proof" in closure_progress["missing_criteria"]
    assert "alternate_ios_receiver_path" in closure_progress["missing_criteria"]

    criteria = Map.new(closure_progress["criteria"], &{&1["id"], &1})
    assert criteria["platform_callback_proof"]["status"] == "missing"
    assert criteria["canonical_parse_proof"]["status"] == "missing"
    assert criteria["mb_fallback_control"]["status"] == "satisfied"

    assert Enum.any?(
             aux["evidence"],
             &String.ends_with?(&1, "aux-closure-progress.json")
           )
  end

  test "completed responder row matches raw GATT fetch logs" do
    rows = read_audit()["rows"] |> Map.new(&{&1["id"], &1})
    responder = rows["hardware_validation_of_full_ios_responder_path"]

    artifacts =
      read_responder_artifacts(
        "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/android-fetch-ios-responder-rerun"
      )

    assert responder["completion_claim_allowed"] == true
    assert artifacts.android_instrumentation =~ "OK (1 test)"
    assert artifacts.ipad_responder =~ "beacon_dispatched"
    assert artifacts.ipad_responder =~ "fetch_responder_advertising_started"
    assert artifacts.ipad_responder =~ "fetch_responder_served"
    assert artifacts.ipad_responder =~ "status=0"

    assert_android_gatt_fetch_completed(artifacts.android_logcat)

    for expected <- [
          "Android observes the iOS MB beacon cue.",
          "Android connects to the iOS MeshxFetchGattResponder service.",
          "Android writes MFQ and reads MFR with GATT status 0.",
          "Android parses the returned MX envelope through the canonical path.",
          "Android instrumentation reports OK (1 test) with terminal event complete."
        ] do
      assert expected in responder["success_criteria"]
    end
  end

  test "completed startup row matches root mix test log" do
    rows = read_audit()["rows"] |> Map.new(&{&1["id"], &1})
    startup = rows["test_startup_friction_no_start_workaround"]

    log =
      "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/manifests/root-mix-test-1210.log"
      |> repo_path()
      |> File.read!()

    assert startup["completion_claim_allowed"] == true
    assert startup["observed_state"]["root_mix_test_without_no_start"] =~ "2026-05-17T12:09:58"
    assert Enum.any?(startup["evidence"], &String.ends_with?(&1, "root-mix-test-1210.log"))

    protocol_count = startup["observed_state"]["test_counts"]["meshx_protocol"]

    for {app, expected} <-
          Map.delete(startup["observed_state"]["test_counts"], "meshx_protocol") do
      assert log =~ "==> #{app}"
      assert log =~ "#{expected} tests, 0 failures"
    end

    assert protocol_count == 47
    assert log =~ "==> meshx_protocol"
    assert log =~ "11 properties, 36 tests, 0 failures"
    refute log =~ "--no-start"
  end

  test "focused audit is linked from the bundle summary" do
    summary =
      "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/summary.json"
      |> read_json()

    assert summary["remaining_items_objective"]["machine_readable_audit_path"] == @audit_path

    assert summary["remaining_items_objective"]["plain_text_audit_path"] ==
             "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/manifests/focused-remaining-items-audit.txt"

    assert summary["remaining_items_objective"]["aux_validation_checklist_path"] ==
             "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/android-aux-full-mx-ios-observe-rerun/aux-validation-checklist.md"

    assert summary["remaining_items_objective"]["upstream_patch_maintainer_handoff_path"] ==
             "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/upstream-pr-recheck-1358/maintainer-handoff.md"

    assert summary["remaining_items_objective"]["upstream_patch_migration_progress_path"] ==
             "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/upstream-pr-recheck-1358/upstream-migration-progress.json"

    assert File.exists?(
             repo_path(summary["remaining_items_objective"]["aux_validation_checklist_path"])
           )

    assert File.exists?(
             repo_path(
               summary["remaining_items_objective"]["upstream_patch_maintainer_handoff_path"]
             )
           )

    assert File.exists?(
             repo_path(
               summary["remaining_items_objective"]["upstream_patch_migration_progress_path"]
             )
           )

    assert summary["remaining_items_objective"]["last_verified_at"] ==
             read_audit()["last_verified_at"]
  end

  test "plain-text focused audit artifact archives checklist output" do
    plain =
      "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/manifests/focused-remaining-items-audit.txt"
      |> repo_path()
      |> File.read!()

    assert plain =~ "REMAINING_ITEMS complete=false completed=2 incomplete=2"
    assert plain =~ "update_goal_allowed=false"
    assert plain =~ "CHECKLIST count=6 objective_success_criteria=4"
    assert plain =~ "ROW id=extended_advertising_interop_aux_scan_response"
    assert plain =~ "ROW id=upstreaming_mob_dev_mob_patches"
    assert plain =~ "CHECKLIST_ITEM id=completion_decision status=blocked"
  end

  test "remaining-items audit doc links closure checklist artifacts" do
    doc =
      "docs/remaining_items_audit.md"
      |> repo_path()
      |> File.read!()

    assert doc =~
             "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/android-aux-full-mx-ios-observe-rerun/aux-validation-checklist.md"

    assert doc =~
             "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/upstream-pr-recheck-1358/maintainer-handoff.md"

    assert doc =~
             "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/upstream-pr-recheck-1358/upstream-migration-progress.json"

    assert doc =~ "The AUX validation checklist records the exact sender/observer metadata"
    assert doc =~ "The maintainer handoff records the upstream merge/release action"
    assert doc =~ "The migration-progress artifact records downstream patch verification"

    assert doc =~
             "Recent evidence inventory preserves iOS emit boundary and closure artifact pointers"

    assert doc =~ "recent-evidence inventory/task suite passed with 8 tests and 0 failures"
    assert doc =~ "direct full-MX AUX completion"
    assert doc =~ "upstream PR merge completion"
  end

  test "upstream patch doc links current maintainer handoff artifacts" do
    doc =
      "docs/upstream_mob_patches.md"
      |> repo_path()
      |> File.read!()

    assert doc =~ "Last verified: 2026-05-17T13:58:54-0700."
    assert doc =~ "GenericJam/mob_dev/pull/6#issuecomment-4471758623"
    assert doc =~ "GenericJam/mob_new/pull/5#issuecomment-4471758634"
    assert doc =~ "hardware/external-blocker-recheck-1358/summary.md"
    assert doc =~ "hardware/upstream-pr-recheck-1358/summary.md"
    assert doc =~ "hardware/upstream-pr-recheck-1358/maintainer-handoff.md"
    assert doc =~ "hardware/upstream-pr-recheck-1358/upstream-migration-progress.json"
    assert doc =~ "current GitHub token has `READ` viewer permission"

    refute doc =~ "external-blocker-recheck-1225"
    refute doc =~ "upstream-pr-recheck-1225"
    refute doc =~ "2026-05-17T12:25:05-0700"
  end

  test "release-candidate review links focused remaining-items artifacts" do
    review =
      "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/release-candidate/review.json"
      |> read_json()

    notes = review["operator_notes"]

    assert notes["focused_remaining_items_audit_path"] ==
             "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/manifests/focused-remaining-items-audit.json"

    assert notes["focused_remaining_items_plain_text_path"] ==
             "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/manifests/focused-remaining-items-audit.txt"

    assert File.exists?(repo_path(notes["focused_remaining_items_audit_path"]))
    assert File.exists?(repo_path(notes["focused_remaining_items_plain_text_path"]))
    assert "direct_full_mx_aux_complete" in review["required_blocked_claims"]
    assert "upstream_patch_migration_complete" in review["required_blocked_claims"]
    assert "direct_full_mx_aux_complete" in notes["blocked_claims_called_out"]
    assert "upstream_patch_migration_complete" in notes["blocked_claims_called_out"]
    assert review["whole_project_complete?"] == false
  end

  test "release-candidate template exposes focused blocked claims" do
    template =
      "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/release-candidate/template.json"
      |> read_json()

    evidence =
      "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/release-candidate/evidence.json"
      |> read_json()

    assert "direct_full_mx_aux_complete" in template["required_blocked_claims"]
    assert "upstream_patch_migration_complete" in template["required_blocked_claims"]
    assert "direct_full_mx_aux_complete" in evidence["required_blocked_claims"]
    assert "upstream_patch_migration_complete" in evidence["required_blocked_claims"]
    assert template["operator_notes"]["blocked_claims_called_out"] == []
  end

  test "closure checklist paths align across summary, release manifest, and candidate review" do
    summary =
      "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/summary.json"
      |> read_json()

    release =
      "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/manifests/local-release.json"
      |> read_json()

    review =
      "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/release-candidate/review.json"
      |> read_json()

    aux_path = summary["remaining_items_objective"]["aux_validation_checklist_path"]
    aux_progress_path = summary["remaining_items_objective"]["aux_closure_progress_path"]
    upstream_path = summary["remaining_items_objective"]["upstream_patch_maintainer_handoff_path"]

    upstream_progress_path =
      summary["remaining_items_objective"]["upstream_patch_migration_progress_path"]

    artifact_paths =
      release["artifact_bundle"]["artifacts"]
      |> Map.new(&{&1["id"], &1["path"]})

    required_artifact_ids = MapSet.new(Enum.map(release["required_artifacts"], & &1["id"]))

    assert artifact_paths["direct_full_mx_aux_validation_checklist"] == aux_path
    assert artifact_paths["upstream_patch_maintainer_handoff"] == upstream_path
    assert "direct_full_mx_aux_validation_checklist" in required_artifact_ids
    assert "upstream_patch_maintainer_handoff" in required_artifact_ids

    assert review["operator_notes"]["direct_full_mx_aux_validation_checklist_path"] == aux_path
    assert review["operator_notes"]["upstream_patch_maintainer_handoff_path"] == upstream_path
    assert File.exists?(repo_path(aux_path))
    assert File.exists?(repo_path(aux_progress_path))
    assert File.exists?(repo_path(upstream_path))
    assert File.exists?(repo_path(upstream_progress_path))

    progress = read_json(aux_progress_path)
    assert progress["completion_claim_allowed"] == false
    assert "platform_callback_proof" in progress["missing_criteria"]

    upstream_progress = read_json(upstream_progress_path)
    assert upstream_progress["completion_claim_allowed"] == false
    assert "upstream_prs_merged" in upstream_progress["missing_criteria"]
  end

  test "recent evidence inventory indexes closure artifacts without closing them" do
    recent =
      "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/manifests/local-release-recent-evidence.json"
      |> read_json()

    summary =
      "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/summary.json"
      |> read_json()

    items = recent["items"] |> Map.new(&{&1["id"], &1})

    aux_path = summary["remaining_items_objective"]["aux_validation_checklist_path"]
    upstream_path = summary["remaining_items_objective"]["upstream_patch_maintainer_handoff_path"]

    upstream_progress_path =
      summary["remaining_items_objective"]["upstream_patch_migration_progress_path"]

    assert recent["item_count"] == 9
    assert recent["release_candidate_complete?"] == false
    assert items["direct_full_mx_aux_validation_checklist"]["source"] == aux_path
    assert items["upstream_patch_maintainer_handoff"]["source"] == upstream_path
    assert items["upstream_patch_migration_progress"]["source"] == upstream_progress_path

    assert "direct_full_mx_aux_interop_complete" in items[
             "direct_full_mx_aux_validation_checklist"
           ]["does_not_support"]

    assert "upstream_prs_merged" in items["upstream_patch_maintainer_handoff"]["does_not_support"]

    assert "meshx_dependency_migration" in items[
             "upstream_patch_migration_progress"
           ]["does_not_support"]

    assert "upstream_patch_migration_complete" in items[
             "upstream_patch_migration_progress"
           ]["does_not_support"]

    assert "whole_project_complete" in recent["blocked_claims"]
  end

  test "release criteria in local release manifest cite focused and recent evidence gates" do
    release =
      "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/manifests/local-release.json"
      |> read_json()

    criteria =
      release["release_criteria"]["criteria"]
      |> Map.new(&{&1["id"], &1})

    audit_artifacts = criteria["release_audit_artifacts"]

    assert "mix meshx.mobile.remaining_items.audit --json --out <path>" in audit_artifacts[
             "evidence"
           ]

    assert "mix meshx.mobile.local_release.recent_evidence --json --out <path>" in audit_artifacts[
             "evidence"
           ]

    assert "LocalFocusedRemainingItemsAudit" in audit_artifacts["evidence"]
    assert "LocalReleaseRecentEvidenceInventory" in audit_artifacts["evidence"]

    assert Enum.any?(
             audit_artifacts["limitations"],
             &String.contains?(
               &1,
               "direct full-MX AUX and upstream patch migration rows incomplete"
             )
           )

    assert Enum.any?(
             audit_artifacts["limitations"],
             &String.contains?(&1, "AUX checklist and upstream handoff pointers")
           )
  end

  test "operator capture plan in local release manifest requires closure paths" do
    release =
      "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/manifests/local-release.json"
      |> read_json()

    manifest_paths =
      release["operator_capture_plan"]["capture_sections"]
      |> Enum.find(&(&1["id"] == "manifest_paths"))

    assert "focused_remaining_items_audit_path" in manifest_paths["required_entries"]
    assert "focused_remaining_items_plain_text_path" in manifest_paths["required_entries"]
    assert "direct_full_mx_aux_validation_checklist_path" in manifest_paths["required_entries"]
    assert "upstream_patch_maintainer_handoff_path" in manifest_paths["required_entries"]
    assert "recent_evidence_inventory_path" in manifest_paths["required_entries"]

    assert Enum.any?(
             manifest_paths["notes"],
             &String.contains?(&1, "AUX validation checklist")
           )

    assert Enum.any?(
             manifest_paths["notes"],
             &String.contains?(&1, "upstream maintainer handoff")
           )
  end

  test "bundle README indexes current blocker checklists and recheck paths" do
    readme =
      "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/README.md"
      |> repo_path()
      |> File.read!()

    assert readme =~ "hardware/external-blocker-recheck-1358/"
    assert readme =~ "hardware/upstream-pr-recheck-1358/"
    assert readme =~ "hardware/android-aux-full-mx-ios-observe-rerun/aux-validation-checklist.md"
    assert readme =~ "hardware/upstream-pr-recheck-1358/maintainer-handoff.md"
    assert readme =~ "hardware/upstream-pr-recheck-1358/upstream-migration-progress.json"
    assert readme =~ "AUX validation checklist and upstream maintainer handoff paths"
    assert readme =~ "direct full-MX AUX completion"
    assert readme =~ "upstream patch migration completion"
    assert readme =~ "The bundle currently lists 54 artifacts"
    assert readme =~ "AUX validation checklist plus upstream maintainer handoff paths"
    assert readme =~ "The direct full-MX AUX row remains blocked"
    assert readme =~ "The upstream patch row remains blocked"

    refute readme =~ "external-blocker-recheck-1225"
    refute readme =~ "upstream-pr-recheck-1225"
    refute readme =~ "2026-05-17T12:25:05-0700"
  end

  test "bundle summary latest blocker sections match archived raw recheck artifacts" do
    summary =
      "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/summary.json"
      |> read_json()

    external = summary["external_blocker_recheck_1358"]
    upstream = summary["upstream_pr_recheck_1358"]

    devices =
      "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/external-blocker-recheck-1358/devicectl-devices.txt"
      |> repo_path()
      |> File.read!()

    assert external["checked_at"] == "2026-05-17T13:58:54-0700"
    assert external["ios_alternate_receiver_available"] == false
    assert devices =~ external["ios_primary_receiver"] |> String.split(" ") |> hd()
    assert devices =~ external["ios_alternate_receiver_state"]

    mob_dev_pr =
      read_json(
        "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/upstream-pr-recheck-1358/mob-dev-pr-6.json"
      )

    mob_new_pr =
      read_json(
        "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/upstream-pr-recheck-1358/mob-new-pr-5.json"
      )

    mob_dev_repo =
      read_json(
        "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/upstream-pr-recheck-1358/mob-dev-repo.json"
      )

    mob_new_repo =
      read_json(
        "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/upstream-pr-recheck-1358/mob-new-repo.json"
      )

    assert_summary_pr_matches_raw(upstream["mob_dev_pr"], mob_dev_pr, mob_dev_repo)
    assert_summary_pr_matches_raw(upstream["mob_new_pr"], mob_new_pr, mob_new_repo)
    assert_summary_pr_matches_raw(external["mob_dev_pr"], mob_dev_pr, mob_dev_repo)
    assert_summary_pr_matches_raw(external["mob_new_pr"], mob_new_pr, mob_new_repo)

    assert upstream["upstream_patch_migration_complete"] == false
    assert external["upstream_patch_migration_complete"] == false
    assert external["direct_full_mx_aux_claim_allowed"] == false

    assert "hardware/upstream-pr-recheck-1358/upstream-migration-progress.json" in upstream[
             "raw_outputs"
           ]

    assert Enum.any?(upstream["notes"], &String.contains?(&1, "Migration-progress JSON"))
  end

  defp read_responder_artifacts(directory) do
    %{
      android_instrumentation:
        File.read!(repo_path(Path.join(directory, "android-instrumentation-2.log"))),
      android_logcat: File.read!(repo_path(Path.join(directory, "android-logcat-2.log"))),
      ipad_responder: File.read!(repo_path(Path.join(directory, "ipad-responder-2.log")))
    }
  end

  defp assert_android_gatt_fetch_completed(log) do
    assert log =~ ~s("event":"fetch_connect_result")
    assert log =~ ~s("gatt_status":0)
    assert log =~ ~s("event":"fetch_service_discovery_result")
    assert log =~ ~s("service_found":true)
    assert log =~ ~s("event":"fetch_characteristic_write_result")
    assert log =~ ~s("event":"fetch_characteristic_read_result")
    assert log =~ ~s("event":"fetch_response_received")
    assert log =~ ~s("status":"ok")
    assert log =~ ~s("envelope_parse":"ok")
    assert log =~ ~s("terminal_event":"complete")
    assert log =~ ~s("reason":"complete")
  end

  defp read_aux_probe_artifacts(directory) do
    %{
      android_logcat: File.read!(repo_path(Path.join(directory, "android-logcat.log"))),
      ipad_log: File.read!(repo_path(Path.join(directory, "ipad-aux-scan-response.log")))
    }
  end

  defp assert_android_started_scan_response(log) do
    assert log =~ ~s("event":"advertising_set_started")
    assert log =~ ~s("payload_size":80)
    assert log =~ ~s("scannable":true)
    assert log =~ ~s("connectable":false)
    assert log =~ ~s("data_carrier":"scan_response")
  end

  defp assert_aux_log_has_no_direct_mx_callback(log) do
    assert count_log_lines(log, "received_message") == 0
    assert count_log_lines(log, "decode") == 0
    assert count_log_lines(log, "candidate") == 0
    assert count_log_lines(log, "FF FF 4D 58") == 0
  end

  defp count_log_lines(log, pattern) do
    log
    |> String.split("\n", trim: true)
    |> Enum.count(&String.contains?(&1, pattern))
  end

  defp assert_upstream_row_matches_raw_artifacts(audit_pr, raw_pr, raw_repo) do
    assert audit_pr["number"] == raw_pr["number"]
    assert audit_pr["state"] == raw_pr["state"]
    assert audit_pr["is_draft"] == raw_pr["isDraft"]
    assert audit_pr["mergeable"] == raw_pr["mergeable"]
    assert audit_pr["merge_state_status"] == raw_pr["mergeStateStatus"]
    assert raw_pr["mergedAt"] == nil
    assert audit_pr["viewer_permission"] == "READ"
    assert repo_viewer_permission(raw_repo) == "READ"

    assert Enum.any?(
             raw_pr["statusCheckRollup"],
             &match?(%{"name" => "GitGuardian Security Checks", "conclusion" => "SUCCESS"}, &1)
           )
  end

  defp assert_summary_pr_matches_raw(summary_pr, raw_pr, raw_repo) do
    assert summary_pr["number"] == raw_pr["number"]
    assert summary_pr["state"] == raw_pr["state"]
    assert summary_pr["is_draft"] == raw_pr["isDraft"]
    assert summary_pr["mergeable"] == raw_pr["mergeable"]
    assert summary_pr["merge_state_status"] == raw_pr["mergeStateStatus"]
    assert summary_pr["head_sha"] == raw_pr["headRefOid"]
    assert raw_pr["mergedAt"] == nil
    assert summary_pr["viewer_permission"] == "READ"
    assert repo_viewer_permission(raw_repo) == "READ"

    assert Enum.any?(raw_pr["comments"], &(&1["url"] == summary_pr["handoff_comment_url"]))

    assert Enum.any?(
             raw_pr["statusCheckRollup"],
             &match?(%{"name" => "GitGuardian Security Checks", "conclusion" => "SUCCESS"}, &1)
           )
  end

  defp read_audit, do: read_json(@audit_path)

  defp repo_viewer_permission(%{"viewerPermission" => permission}), do: permission

  defp repo_viewer_permission(%{
         "viewer_permission" => %{"pull" => true, "push" => false, "admin" => false}
       }),
       do: "READ"

  defp read_json(path) do
    path
    |> repo_path()
    |> File.read!()
    |> JSON.decode!()
  end

  defp repo_path(path) do
    cwd = File.cwd!()

    repo_root =
      if Path.basename(cwd) == "meshx_mobile_app" do
        Path.expand("../..", cwd)
      else
        cwd
      end

    Path.join(repo_root, path)
  end
end
