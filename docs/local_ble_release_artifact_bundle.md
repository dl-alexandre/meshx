# Local BLE Release Artifact Bundle

This checklist packages the current validated mode:

`advertisement-only local mesh`

It is not a whole-project completion artifact. It exists so an operator can
archive the evidence needed for an advert-only local release candidate without
claiming full delivery, trust, routing, background operation, or iOS parity.

## Required Bundle Files

Generate and archive:

```bash
mix mob.node.local_readiness.audit --allow-open --out tmp/local-readiness.json
mix mob.node.local_completion.audit --allow-open | tee tmp/local-completion-audit.txt
mix mob.node.local_completion.audit --allow-open --json --out tmp/local-completion-audit.json
mix mob.node.local_completion.blocker_matrix --json --out tmp/local-completion-blocker-matrix.json
mix mob.node.remaining_items.audit --json --out artifacts/local-ble/<run-id>/manifests/focused-remaining-items-audit.json
mix mob.node.remaining_items.audit | tee artifacts/local-ble/<run-id>/manifests/focused-remaining-items-audit.txt
mix mob.node.local_release.manifest --json --out tmp/local-release.json
mix mob.node.local_release.recent_evidence --json --out tmp/local-release-recent-evidence.json
mix mob.node.advert_gossip.audit apps/mob_node/test/fixtures/advert_gossip_scenarios > tmp/advert-gossip-audit.txt
mix mob.node.local_release.artifact_bundle --json --out tmp/local-release-artifact-bundle.json
```

For Nearby Messages product-UX evidence, generate the operator metadata
scaffold before attaching target-device screenshots or notes:

```bash
mix mob.node.local_inbox.ux_review --template --out artifacts/local-ble/<run-id>/ux/evidence.json
```

Fill the generated JSON with real target-device metadata and operator evidence:

- `target_devices`: device id, model, OS/API version, screen size class, app
  build id, and evidence directory.
- `state_evidence`: `evidence_kind` of `screenshot` or `operator_note`,
  plus screenshot path or operator note for `full_message`, `unresolved_ref`,
  `gossiped_ref`, and `stale_ref` on every target device.
- `interaction_evidence`: `evidence_kind` of `screenshot` or `operator_note`,
  plus filter change, sort change, row selection, and detail panel evidence on
  every target device.
- `selected_detail_evidence`: `evidence_kind` of `screenshot` or
  `operator_note`, plus selected-detail artifact path or note for
  `full_message`, `unresolved_ref`, `gossiped_ref`, and `stale_ref` on every
  target device.
- `copy_review`: `evidence_kind` of `screenshot` or `operator_note`, review
  path, reviewed target device ids, allowed wording, blocked claims, warning
  text, control summaries, per-state blocked-claim copy, and selected
  detail-panel copy.
- `visual_density_review`: `evidence_kind` of `screenshot` or `operator_note`,
  reviewed target device ids, row truncation, wrapping, tap targets, detail
  readability, and densest fixture capture.

Then run:

```bash
mix mob.node.local_inbox.ux_review --input artifacts/local-ble/<run-id>/ux/evidence.json --json --out tmp/local-inbox-ux-review.json
```

The generated template is intentionally incomplete. It is not product-UX
approval and must review as open until real operator evidence is attached.
The review output must report `coverage_summary` with state, interaction,
selected-detail, copy-review, and density coverage before product-facing
Nearby Messages wording can be accepted.

The release manifest embeds:

- `completion_audit`: the whole-project completion claim gate.
- `hardware_evidence`: the hardware validation gates.
- `artifact_bundle`: this release-candidate packaging checklist.

The standalone blocker matrix artifact classifies remaining completion work by
hardware, transport, product, implementation, security, and release-evidence
blockers.

Also review the plain-text blocker matrix output. It must include
`HARDWARE_BLOCKED objectives=...` and `NO_NEW_HARDWARE objectives=...` lines
so physical blockers stay separated from planning and release-evidence work.

The standalone completion audit artifact is the top-level claim gate. It must
remain archived even when an advert-only release candidate is allowed, because
it records that whole-project completion is still false while blocked and
partial objectives remain open.

Also review the plain-text completion audit output. It must include the
`PROMPT_CHECKLIST 10 objectives=...` line so the ordered remaining-objective
spine is visible without opening the full JSON artifact. It must also include
`OPEN_ITEMS 10` plus one `OPEN_ITEM objective=... status=... missing=...` line
for each remaining objective, so the release review can see every blocked or
partial project area directly in the command output.

Review `tmp/local-release-artifact-bundle.json` for its `required_commands`
list before accepting the bundle. The list is the generated command surface
that keeps readiness, completion, evidence, review, format, and diff gates
visible to operators.

## Operator Attachments

Attach concrete hardware evidence under a run-specific directory, for example:

```text
artifacts/local-ble/<run-id>/hardware/
```

Current archived Android evidence:

```text
artifacts/local-ble/2026-05-12-sm-t577u-sm-t390/
artifacts/local-ble/2026-05-13-sm-t577u-sm-t390/hardware/m40-gatt-interop-rerun/
```

The May 12 bundle contains the current M26 full-envelope failure, M26B legacy
beacon success, readiness manifest, release manifest, advert gossip audit
output, and operator wording notes. The May 13 archive refreshes the
standalone M40 GATT blocker evidence from the current tree: both
SM-T577U -> SM-T390 and SM-T390 -> SM-T577U still fail with Android status 133
before service discovery.

Each attachment should identify:

- device model;
- OS/API version;
- device role;
- command or harness used;
- summary path;
- raw logs or validation ledger;
- gate IDs and the gate-specific evidence type for each cited gate.

If a hardware gate is open, keep it visible in release notes. Do not replace a
missing hardware log with replay evidence.

For the current SM-T577U / SM-T390 pair, release candidates must keep the
May 13 standalone GATT archive linked as known-bad transport evidence. It
supports the blocker record only; it does not satisfy the known-good transport
or full-message-resolution gates.

Run the operator-supplied paths, hardware attachment metadata, and release-note
wording through:

```elixir
Mob.Node.BLE.LocalReleaseCandidateEvidenceReview.review(input)
```

Minimum review input shape:

```elixir
%{
  readiness_manifest_path: "tmp/local-readiness.json",
  completion_audit_path: "tmp/local-completion-audit.json",
  completion_audit_plain_text_path: "tmp/local-completion-audit.txt",
  focused_remaining_items_audit_path: "artifacts/local-ble/<run-id>/manifests/focused-remaining-items-audit.json",
  focused_remaining_items_plain_text_path: "artifacts/local-ble/<run-id>/manifests/focused-remaining-items-audit.txt",
  direct_full_mx_aux_validation_checklist_path: "artifacts/local-ble/<run-id>/hardware/android-aux-full-mx-ios-observe-rerun/aux-validation-checklist.md",
  upstream_patch_maintainer_handoff_path: "artifacts/local-ble/<run-id>/hardware/upstream-pr-recheck-<hhmm>/maintainer-handoff.md",
  release_manifest_path: "tmp/local-release.json",
  recent_evidence_inventory_path: "tmp/local-release-recent-evidence.json",
  completion_blocker_matrix_path: "tmp/local-completion-blocker-matrix.json",
  advert_gossip_audit_path: "tmp/advert-gossip-audit.txt",
  persistence_lifecycle_plan_path: "tmp/local-persistence-lifecycle-plan.json",
  persistence_lifecycle: %{
    plan_path: "tmp/local-persistence-lifecycle-plan.json",
    plan_version: 1,
    boundary: :production_default_local_inbox_persistence_plan,
    current_default_mode: :memory_only,
    opt_in_durable_snapshots_available?: true,
    production_default_persistence_allowed?: false,
    default_lifecycle_claim_allowed?: false,
    gate_count: 6,
    blocked_gate_count: 6
  },
  lifecycle_review_path: "tmp/local-lifecycle-hardware-review.json",
  lifecycle_review: %{
    review_path: "tmp/local-lifecycle-hardware-review.json",
    review_version: 1,
    boundary: :mobile_ble_lifecycle_hardware_evidence_review,
    status: :ready,
    lifecycle_hardware_evidence_complete?: true,
    android_foreground_service_claim_allowed?: false,
    android_background_ble_claim_allowed?: false,
    ios_background_claim_allowed?: false,
    background_ble_claim_allowed?: false,
    restart_claim_allowed?: false,
    scheduled_retry_claim_allowed?: false,
    background_gossip_claim_allowed?: false,
    delivery_claim_allowed?: false
  },
  ios_parity_review_path: "tmp/local-ios-parity-hardware-review.json",
  ios_parity_review: %{
    review_path: "tmp/local-ios-parity-hardware-review.json",
    review_version: 1,
    boundary: :ios_advert_only_hardware_evidence_review,
    status: :ready,
    ios_hardware_evidence_complete?: true,
    ios_participation_claim_allowed?: false,
    ios_hardware_claim_allowed?: false,
    ios_legacy_beacon_observe_claim_allowed?: false,
    ios_legacy_beacon_gossip_claim_allowed?: false,
    ios_full_envelope_advert_claim_allowed?: false,
    ios_background_ble_claim_allowed?: false,
    ios_parity_claim_allowed?: false
  },
  full_resolution_review_path: "tmp/local-full-resolution-transport-review.json",
  full_resolution_review: %{
    review_path: "tmp/local-full-resolution-transport-review.json",
    review_version: 1,
    boundary: :full_message_resolution_transport_evidence_review,
    status: :ready,
    full_resolution_transport_evidence_complete?: true,
    real_fetch_transport_validated?: false,
    full_message_resolution_claim_allowed?: false,
    known_good_transport_claim_allowed?: false,
    gatt_fetch_success_claim_allowed?: false,
    message_delivery_claim_allowed?: false,
    trusted_message_claim_allowed?: false
  },
  known_good_transport_review_path: "tmp/local-known-good-transport-review.json",
  known_good_transport_review: %{
    review_path: "tmp/local-known-good-transport-review.json",
    review_version: 1,
    boundary: :known_good_transport_evidence_review,
    status: :ready,
    known_good_transport_evidence_complete?: true,
    known_good_transport_claim_allowed?: false,
    gatt_fetch_success_claim_allowed?: false,
    full_message_resolution_claim_allowed?: false,
    message_delivery_claim_allowed?: false
  },
  multi_hop_review_path: "tmp/local-multi-hop-hardware-review.json",
  multi_hop_review: %{
    review_path: "tmp/local-multi-hop-hardware-review.json",
    review_version: 1,
    boundary: :multi_hop_hardware_evidence_review,
    status: :ready,
    multi_hop_hardware_evidence_complete?: true,
    multi_hop_physical_proof_present?: false,
    multi_hop_hardware_gossip_claim_allowed?: false,
    routed_delivery_claim_allowed?: false,
    guaranteed_delivery_claim_allowed?: false,
    trusted_delivery_claim_allowed?: false,
    background_operation_claim_allowed?: false
  },
  security_review_path: "tmp/local-security-release-review.json",
  security_review: %{
    review_path: "tmp/local-security-release-review.json",
    review_version: 1,
    boundary: :local_security_release_evidence_review,
    status: :ready,
    security_release_evidence_complete?: true,
    authenticated_peer_identity_claim_allowed?: false,
    authenticated_message_claim_allowed?: false,
    trusted_message_claim_allowed?: false,
    trusted_delivery_claim_allowed?: false
  },
  routing_review_path: "tmp/local-routing-production-review.json",
  routing_review: %{
    review_path: "tmp/local-routing-production-review.json",
    review_version: 1,
    boundary: :production_routing_evidence_review,
    status: :ready,
    production_routing_evidence_complete?: true,
    route_table_claim_allowed?: false,
    route_selection_claim_allowed?: false,
    forwarding_claim_allowed?: false,
    routed_delivery_claim_allowed?: false,
    guaranteed_delivery_claim_allowed?: false,
    multi_hop_hardware_claim_allowed?: false
  },
  ux_review_path: "tmp/local-inbox-ux-review.json",
  ux_review: %{
    review_path: "tmp/local-inbox-ux-review.json",
    review_version: 1,
    boundary: :nearby_messages_on_device_ux_evidence,
    status: :ready,
    on_device_ux_evidence_complete?: true,
    production_ux_claim_allowed?: false,
    delivery_claim_allowed?: false,
    trusted_delivery_claim_allowed?: false,
    routing_claim_allowed?: false,
    target_device_count: 1,
    all_target_devices_have_state_coverage?: true,
    all_target_devices_have_interaction_coverage?: true,
    all_target_devices_have_selected_detail_coverage?: true,
    all_target_devices_copy_reviewed?: true,
    all_target_devices_density_reviewed?: true
  },
  hardware_attachments: [
    %{
      device_model: "SM-T577U",
      os_or_api_version: "Android 13 / API 33",
      role: "legacy beacon sender",
      command_or_harness: "android_ble_message_delivery_two_device.sh",
      summary_path: "artifacts/local-ble/<run-id>/summary.json",
      raw_log_path: "artifacts/local-ble/<run-id>/hardware/sender.logcat",
      gate_ids: [:android_legacy_beacon_gossip_one_hop],
      evidence_types_by_gate: %{
        android_legacy_beacon_gossip_one_hop: :android_legacy_beacon_gossip_summary
      }
    }
  ],
  operator_notes: %{
    notes_path: "docs/local_ble_release_artifact_bundle.md",
    allowed_wording: "MeshX can show messages seen nearby from passive BLE advertisement observations.",
    blocked_claims_called_out: [
      :whole_project_complete,
      :guaranteed_delivery,
      :trusted_delivery,
      :authenticated_message_delivery,
      :routed_delivery,
      :multi_hop_hardware_delivery,
      :full_message_resolution_from_beacon_refs,
      :background_mobile_operation,
      :ios_advert_only_participation,
      :direct_full_mx_aux_complete,
      :upstream_patch_migration_complete
    ],
    open_hardware_gate_ids_called_out: [
      :android_full_envelope_advert_pair,
      :gatt_known_good_fetch,
      :advert_gossip_multi_hop_hardware,
      :ios_advert_only_participation
    ],
    readiness_manifest_path: "tmp/local-readiness.json",
    completion_audit_path: "tmp/local-completion-audit.json",
    completion_audit_plain_text_path: "tmp/local-completion-audit.txt",
    focused_remaining_items_audit_path: "artifacts/local-ble/<run-id>/manifests/focused-remaining-items-audit.json",
    focused_remaining_items_plain_text_path: "artifacts/local-ble/<run-id>/manifests/focused-remaining-items-audit.txt",
    direct_full_mx_aux_validation_checklist_path: "artifacts/local-ble/<run-id>/hardware/android-aux-full-mx-ios-observe-rerun/aux-validation-checklist.md",
    upstream_patch_maintainer_handoff_path: "artifacts/local-ble/<run-id>/hardware/upstream-pr-recheck-<hhmm>/maintainer-handoff.md",
    completion_blocker_matrix_path: "tmp/local-completion-blocker-matrix.json",
    release_manifest_path: "tmp/local-release.json",
    recent_evidence_inventory_path: "tmp/local-release-recent-evidence.json",
    persistence_lifecycle_plan_path: "tmp/local-persistence-lifecycle-plan.json",
    lifecycle_review_path: "tmp/local-lifecycle-hardware-review.json",
    ios_parity_review_path: "tmp/local-ios-parity-hardware-review.json",
    full_resolution_review_path: "tmp/local-full-resolution-transport-review.json",
    known_good_transport_review_path: "tmp/local-known-good-transport-review.json",
    multi_hop_review_path: "tmp/local-multi-hop-hardware-review.json",
    routing_review_path: "tmp/local-routing-production-review.json",
    security_review_path: "tmp/local-security-release-review.json",
    ux_review_path: "tmp/local-inbox-ux-review.json"
  }
}
```

The review must be `:ready` before the artifact bundle is accepted for an
advert-only local release candidate. A ready review still does not close
whole-project completion or any open hardware gate.
Operator-note artifact paths must exactly match the corresponding top-level
release-candidate paths, so notes cannot cite stale readiness, completion,
focused remaining-items, AUX validation checklist, upstream maintainer handoff,
blocker-matrix, release-manifest, recent-evidence, persistence-lifecycle,
lifecycle-review, ios-parity-review, full-resolution-review,
known-good-transport-review, multi-hop-review, routing-review, security-review,
or UX review artifacts.

## Allowed Wording

Use:

> MeshX can show messages seen nearby from passive BLE advertisement observations.

Legacy beacon refs are unresolved pointers. Full-envelope adverts are shown only
when capability-proven and canonical envelope validation passes.

## Blocked Wording

Do not claim:

- whole-project completion;
- guaranteed delivery;
- trusted or authenticated message delivery;
- routed or multi-hop hardware delivery;
- full message resolution from beacon refs;
- background mobile operation;
- iOS advert-only participation;
- direct full-MX AUX completion;
- upstream patch migration completion.

The machine-readable source of truth is:

```elixir
Mob.Node.BLE.LocalReleaseArtifactBundle.snapshot()
```
