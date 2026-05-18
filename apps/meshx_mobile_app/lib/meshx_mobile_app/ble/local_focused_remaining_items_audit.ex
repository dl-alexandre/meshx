defmodule MeshxMobileApp.BLE.LocalFocusedRemainingItemsAudit do
  @moduledoc """
  Focused audit for the four-row updated remaining-items thread objective.

  This is narrower than the whole-project completion audit. It records the
  current evidence and completion decision for the responder hardware path,
  direct full-MX AUX interop, upstream mob patch migration, and the root
  `mix test` startup-friction row. It does not inspect hardware or GitHub.
  """

  @last_verified_at "2026-05-17T13:58:54-0700"

  @completed_rows [
    :hardware_validation_of_full_ios_responder_path,
    :test_startup_friction_no_start_workaround
  ]

  @incomplete_rows [
    :extended_advertising_interop_aux_scan_response,
    :upstreaming_mob_dev_mob_patches
  ]

  @objective_success_criteria [
    "Hardware validation of the full iOS responder path is complete when Android beacon cue -> iOS responder MX service -> Android GATT fetch succeeds on attached hardware.",
    "Extended advertising interop is complete only when direct full-MX AUX scan-response bytes surface to the tested platform scanner callback and parse canonically.",
    "Upstreaming the mob_dev / mob patches is complete only after upstream merge/release, MeshX dependency migration, downstream patch removal, and post-migration verification.",
    "Test startup friction is complete when the umbrella root mix test passes without --no-start."
  ]

  @rows [
    %{
      id: :hardware_validation_of_full_ios_responder_path,
      priority: :high,
      status: :complete_for_attached_sm_t577u_to_ipad12_1_foreground_hardware,
      success_criteria: [
        "Android observes the iOS MB beacon cue.",
        "Android connects to the iOS MeshxFetchGattResponder service.",
        "Android writes MFQ and reads MFR with GATT status 0.",
        "Android parses the returned MX envelope through the canonical path.",
        "Android instrumentation reports OK (1 test) with terminal event complete."
      ],
      evidence: [
        "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/android-fetch-ios-responder-rerun/summary.md",
        "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/android-fetch-ios-responder-rerun/android-instrumentation-2.log",
        "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/android-fetch-ios-responder-rerun/android-logcat-2.log",
        "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/android-fetch-ios-responder-rerun/ipad-responder-2.log",
        "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/summary.json",
        "docs/ble_transport_re_evaluation.md"
      ],
      remaining_gap:
        "None for the requested attached-hardware foreground responder path. This does not prove background BLE, routing, ACKs, trusted delivery, or direct full-MX AUX advertising.",
      completion_claim_allowed: true
    },
    %{
      id: :extended_advertising_interop_aux_scan_response,
      priority: :medium,
      status: :still_limited_blocked_on_tested_ios_hardware,
      success_criteria: [
        "A hardware/API capture shows FF FF 4D 58 MX manufacturer data delivered to the platform scanner callback.",
        "The capture records sender and observer metadata, scan/filter settings, advertising mode, carrier, and payload length.",
        "The observer parses the delivered bytes into canonical received_message / MX envelope handling.",
        "The same run proves the MB beacon fallback still works."
      ],
      evidence: [
        "docs/BLE_BRIDGE.md#extended-advertising-aux-delivery-limitation",
        "apps/meshx_mobile_app/lib/meshx_mobile_app/ble/local_ios_advert_carrier_decision.ex",
        "apps/meshx_mobile_app/lib/meshx_mobile_app/ble/local_hardware_validation_gates.ex",
        "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/android-aux-full-mx-ios-observe/summary.md",
        "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/android-aux-full-mx-ios-observe-rerun/summary.md",
        "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/android-aux-full-mx-ios-observe-rerun/aux-validation-checklist.md",
        "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/android-aux-full-mx-ios-observe-rerun/aux-closure-progress.json",
        "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/aux-alternate-ios-target-check/summary.md",
        "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/external-blocker-recheck-1358/summary.md"
      ],
      observed_state: %{
        android_aux_payload_size: 80,
        android_aux_carrier: :scan_response,
        ios_legacy_beacon_lines_first_probe: 276,
        ios_legacy_beacon_lines_rerun: 120,
        ios_received_message_lines: 0,
        ios_decode_error_lines: 0,
        ios_candidate_discovery_lines: 0,
        ios_mx_aux_callback_lines: 0,
        alternate_ios_receiver_available: false
      },
      remaining_gap:
        "No tested iOS receiver surfaced direct full-MX AUX manufacturer data to the scanner callback. A future hardware/API path must produce callback and canonical parse evidence.",
      completion_claim_allowed: false
    },
    %{
      id: :upstreaming_mob_dev_mob_patches,
      priority: :medium,
      status: :advanced_to_upstream_prs_not_merged,
      success_criteria: [
        "GenericJam/mob_dev#6 is merged and released.",
        "GenericJam/mob_new#5 is merged and released.",
        "MeshX migrates to released dependency versions containing the extension points.",
        "Downstream patch files and mix meshx.patch_deps requirement are removed.",
        "Post-migration MeshX verification gates pass."
      ],
      evidence: [
        "docs/upstream_mob_patches.md",
        "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/upstream-pr-recheck-1358/summary.md",
        "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/upstream-pr-recheck-1358/mob-dev-pr-6.json",
        "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/upstream-pr-recheck-1358/mob-new-pr-5.json",
        "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/upstream-pr-recheck-1358/mob-dev-repo.json",
        "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/upstream-pr-recheck-1358/mob-new-repo.json",
        "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/upstream-pr-recheck-1358/maintainer-handoff.md",
        "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/upstream-pr-recheck-1358/upstream-migration-progress.json",
        "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/manifests/patch-deps-check-1212.log"
      ],
      observed_state: %{
        mob_dev_pr: %{
          repo: "GenericJam/mob_dev",
          number: 6,
          state: :OPEN,
          is_draft: false,
          mergeable: :MERGEABLE,
          merge_state_status: :UNSTABLE,
          visible_check: "GitGuardian Security Checks passed",
          viewer_permission: :READ
        },
        mob_new_pr: %{
          repo: "GenericJam/mob_new",
          number: 5,
          state: :OPEN,
          is_draft: false,
          mergeable: :MERGEABLE,
          merge_state_status: :UNSTABLE,
          visible_check: "GitGuardian Security Checks passed",
          viewer_permission: :READ
        },
        downstream_patch_check: "mix meshx.patch_deps --check passed at 2026-05-17T12:12:03-0700"
      },
      remaining_gap:
        "Both upstream PRs are open and this checkout has READ permission only. A GenericJam maintainer must merge/release before MeshX can migrate off downstream patches.",
      completion_claim_allowed: false
    },
    %{
      id: :test_startup_friction_no_start_workaround,
      priority: :low,
      status: :complete,
      success_criteria: [
        "Root mix test runs without --no-start.",
        "The prior MeshxRuntime/MeshxNoise.Supervisor startup conflict does not fail umbrella tests.",
        "Runtime and scripts preserve explicit dependency startup behavior."
      ],
      evidence: [
        "apps/meshx_runtime/lib/meshx_runtime.ex",
        "scripts/tcp_sender.exs",
        "scripts/tcp_receiver.exs",
        "scripts/tcp_relay_node.exs",
        "scripts/ble_sender.exs",
        "scripts/ble_receiver.exs",
        "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/manifests/root-mix-test-1210.log",
        "docs/remaining_items_audit.md"
      ],
      observed_state: %{
        root_mix_test_without_no_start: "passed at 2026-05-17T12:09:58-0700",
        test_counts: %{
          meshx_transport: 59,
          meshx_protocol: 47,
          meshx_noise: 18,
          meshx_store: 30,
          meshx_mob: 15,
          meshx_transport_ble: 10,
          meshx_runtime: 70,
          meshx_mobile_app: 1265
        }
      },
      remaining_gap: "None for the umbrella startup conflict.",
      completion_claim_allowed: true
    }
  ]

  @prompt_to_artifact_checklist [
    %{
      id: :objective_scope,
      requirement: "Updated Remaining Items four-row objective is represented exactly.",
      row_ids: @completed_rows ++ @incomplete_rows,
      evidence_paths: [
        "docs/remaining_items_audit.md",
        "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/manifests/focused-remaining-items-audit.json",
        "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/manifests/focused-remaining-items-audit.txt"
      ],
      commands: [
        "mix meshx.mobile.remaining_items.audit --json --out <path>",
        "mix meshx.mobile.remaining_items.audit | tee <path>"
      ],
      tests: [
        "apps/meshx_mobile_app/test/meshx_mobile_app/ble/local_focused_remaining_items_audit_test.exs",
        "apps/meshx_mobile_app/test/meshx_mobile_app/ble/focused_remaining_items_audit_artifact_test.exs",
        "apps/meshx_mobile_app/test/mix/tasks/meshx_mobile_remaining_items_audit_test.exs"
      ],
      status: :partial,
      gap: "Two of the four rows remain incomplete, so the objective cannot be marked complete."
    },
    %{
      id: :full_ios_responder_path,
      requirement:
        "High-priority Android beacon cue -> iOS responder serving MX -> Android fetch validation.",
      row_ids: [:hardware_validation_of_full_ios_responder_path],
      evidence_paths: [
        "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/android-fetch-ios-responder-rerun/summary.md",
        "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/android-fetch-ios-responder-rerun/android-instrumentation-2.log",
        "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/android-fetch-ios-responder-rerun/android-logcat-2.log",
        "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/android-fetch-ios-responder-rerun/ipad-responder-2.log",
        "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/summary.json"
      ],
      commands: ["Android IOSResponderFetchSmokeTest hardware run"],
      tests: [
        "apps/meshx_mobile_app/test/meshx_mobile_app/ble/focused_remaining_items_audit_artifact_test.exs"
      ],
      status: :complete_for_attached_hardware,
      gap:
        "Does not prove background BLE, routing, ACKs, trusted delivery, or direct full-MX AUX advertising."
    },
    %{
      id: :extended_advertising_interop,
      requirement: "Medium-priority direct full-MX AUX scan-response interop.",
      row_ids: [:extended_advertising_interop_aux_scan_response],
      evidence_paths: [
        "docs/BLE_BRIDGE.md#extended-advertising-aux-delivery-limitation",
        "apps/meshx_mobile_app/lib/meshx_mobile_app/ble/local_ios_advert_carrier_decision.ex",
        "apps/meshx_mobile_app/lib/meshx_mobile_app/ble/local_hardware_validation_gates.ex",
        "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/android-aux-full-mx-ios-observe/summary.md",
        "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/android-aux-full-mx-ios-observe-rerun/summary.md",
        "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/android-aux-full-mx-ios-observe-rerun/aux-validation-checklist.md",
        "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/android-aux-full-mx-ios-observe-rerun/aux-closure-progress.json",
        "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/aux-alternate-ios-target-check/summary.md",
        "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/external-blocker-recheck-1358/summary.md"
      ],
      commands: [
        "Android IOSAuxFullMxAdvertSmokeTest (scan-response carrier) hardware run",
        "Android IOSAuxFullMxAdvertSmokeTest (primary channel / extendedConnectable=true) — temporarily set extendedConnectable: true in the test for this variant",
        "Android service-data carrier experiment (different advertising strategy) — run emitsServiceDataFullMxEnvelope() in IOSAuxFullMxAdvertSmokeTest (uses MESHX_DIRECT_MX_SERVICE_UUID); pair with iOS observer using --meshx-log-raw-advert-data (look for mx_magic_seen=true or [MX_MAGIC] in the raw dump)",
        "Android hybrid experiment (MB legacy cue + service-data full payload) — run emitsHybridMbCuePlusServiceDataFullMxEnvelope() in IOSAuxFullMxAdvertSmokeTest; pair with iOS observer using --meshx-log-raw-advert-data (look for mx_magic_seen=true on both the MB cue and the service-data UUID)",
        "iOS direct-MX service-data emit experiment (reverse direction) — iOS harness with --meshx-auto-direct-mx-service-advertise (emits full MX on the direct service UUID); pair with Android service-data / raw observer to test iOS → Android on the new carrier",
        "iOS hybrid emit (MB cue + direct service-data full payload) — iOS harness with --meshx-auto-direct-mx-hybrid-advertise; the symmetric iOS→Android version of the Android hybrid test. Pair with Android raw observer and look for matching messageId in both the MB beacon and the DIRECT_MX_SERVICE_DATA_WITH_MAGIC log.",
        "iOS observer (with raw dump for all carriers): xcrun devicectl device process launch --device <udid> --terminate-existing --console dev.meshx.mobile.harness -- --meshx-auto-scan --meshx-log-candidate-discoveries --meshx-log-raw-advert-data"
      ],
      tests: [
        "apps/meshx_mobile_app/test/meshx_mobile_app/ble/focused_remaining_items_audit_artifact_test.exs",
        "apps/meshx_mobile_app/test/meshx_mobile_app/ble/local_hardware_validation_gates_test.exs"
      ],
      status: :blocked,
      gap:
        "No tested iOS receiver surfaced direct full-MX AUX manufacturer data to the scanner callback."
    },
    %{
      id: :upstream_mob_patch_migration,
      requirement: "Medium-priority upstreaming of mob_dev and mob patches.",
      row_ids: [:upstreaming_mob_dev_mob_patches],
      evidence_paths: [
        "docs/upstream_mob_patches.md",
        "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/upstream-pr-recheck-1358/summary.md",
        "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/upstream-pr-recheck-1358/mob-dev-pr-6.json",
        "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/upstream-pr-recheck-1358/mob-new-pr-5.json",
        "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/upstream-pr-recheck-1358/mob-dev-repo.json",
        "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/upstream-pr-recheck-1358/mob-new-repo.json",
        "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/upstream-pr-recheck-1358/maintainer-handoff.md",
        "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/upstream-pr-recheck-1358/upstream-migration-progress.json",
        "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/manifests/patch-deps-check-1212.log"
      ],
      commands: ["mix meshx.patch_deps --check", "gh pr view / gh api upstream recheck"],
      tests: [
        "apps/meshx_mobile_app/test/meshx_mobile_app/ble/focused_remaining_items_audit_artifact_test.exs",
        "apps/meshx_mobile_app/test/meshx_mobile_app/ble/local_project_readiness_test.exs"
      ],
      status: :blocked,
      gap:
        "Both upstream PRs remain open; MeshX has not migrated to released upstream dependency versions and still needs downstream patches."
    },
    %{
      id: :test_startup_friction,
      requirement: "Low-priority umbrella mix test startup friction without --no-start.",
      row_ids: [:test_startup_friction_no_start_workaround],
      evidence_paths: [
        "apps/meshx_runtime/lib/meshx_runtime.ex",
        "scripts/tcp_sender.exs",
        "scripts/tcp_receiver.exs",
        "scripts/tcp_relay_node.exs",
        "scripts/ble_sender.exs",
        "scripts/ble_receiver.exs",
        "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/manifests/root-mix-test-1210.log"
      ],
      commands: ["mix test"],
      tests: [
        "apps/meshx_mobile_app/test/meshx_mobile_app/ble/focused_remaining_items_audit_artifact_test.exs"
      ],
      status: :complete,
      gap: "None for the umbrella startup conflict."
    },
    %{
      id: :completion_decision,
      requirement:
        "update_goal may only be allowed after every explicit row is complete and verified by artifacts.",
      row_ids: @completed_rows ++ @incomplete_rows,
      evidence_paths: [
        "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/manifests/focused-remaining-items-audit.json",
        "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/manifests/focused-remaining-items-audit.txt"
      ],
      commands: [
        "mix meshx.mobile.remaining_items.audit --json --out <path>",
        "mix meshx.mobile.remaining_items.audit | tee <path>"
      ],
      tests: [
        "apps/meshx_mobile_app/test/meshx_mobile_app/ble/local_focused_remaining_items_audit_test.exs",
        "apps/meshx_mobile_app/test/meshx_mobile_app/ble/focused_remaining_items_audit_artifact_test.exs"
      ],
      status: :blocked,
      gap:
        "extended_advertising_interop_aux_scan_response and upstreaming_mob_dev_mob_patches are incomplete."
    }
  ]

  @spec snapshot() :: map()
  def snapshot do
    %{
      audit: :updated_remaining_items,
      audit_version: 1,
      last_verified_at: @last_verified_at,
      objective: "Track the four updated remaining items after the iOS responder implementation.",
      objective_success_criteria: @objective_success_criteria,
      complete: false,
      completed_rows: @completed_rows,
      incomplete_rows: @incomplete_rows,
      rows: @rows,
      prompt_to_artifact_checklist: @prompt_to_artifact_checklist,
      completion_decision: %{
        complete: false,
        reason:
          "The AUX/direct full-MX row and upstream mob patch migration row remain incomplete.",
        update_goal_allowed: false
      }
    }
  end

  @spec json_snapshot() :: map()
  def json_snapshot do
    snapshot()
    |> JSON.encode!()
    |> JSON.decode!()
  end
end
