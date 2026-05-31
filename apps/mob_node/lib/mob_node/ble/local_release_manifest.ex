defmodule Mob.Node.BLE.LocalReleaseManifest do
  @moduledoc """
  Machine-readable release manifest for the validated advert-only local mode.

  This manifest ties together release criteria, project readiness, policy
  gates, and required verification commands. It is a release/readiness
  artifact, not a runtime behavior. It does not inspect hardware, scan,
  advertise, fetch, route, persist, ACK, retry, encrypt, or run background
  work.
  """

  alias Mob.Node.BLE.{
    LocalFullMessageResolutionEvidenceManifest,
    LocalIOSParityEvidenceManifest,
    LocalIOSParityPolicy,
    LocalInboxUxEvidenceManifest,
    LocalLifecycleEvidenceManifest,
    LocalLifecyclePolicy,
    LocalMultiHopHardwareEvidenceManifest,
    LocalPersistenceEvidenceManifest,
    LocalProjectCompletionAudit,
    LocalProjectReadiness,
    LocalReleaseArtifactBundle,
    LocalReleaseCriteria,
    LocalReleaseEvidenceManifest,
    LocalReleaseOperatorCapturePlan,
    LocalRoutingEvidenceManifest,
    LocalRoutingPolicy,
    LocalSecurityEvidenceManifest,
    LocalTrustPolicy
  }

  @required_commands [
    "mix test",
    "mix mob.node.advert_gossip.audit apps/mob_node/test/fixtures/advert_gossip_scenarios",
    "mix mob.node.local_completion.audit --allow-open",
    "mix mob.node.local_completion.audit --allow-open | tee tmp/local-completion-audit.txt",
    "mix mob.node.local_completion.audit --allow-open --json --out <path>",
    "mix mob.node.local_completion.audit --allow-open --json --out tmp/ci-local-completion-audit.json",
    "mix mob.node.local_completion.blocker_matrix --json --out <path>",
    "mix mob.node.local_completion.blocker_matrix --json --out tmp/local-completion-blocker-matrix.json",
    "mix mob.node.remaining_items.audit --json --out <path>",
    "mix mob.node.remaining_items.audit | tee <path>",
    "mix mob.node.local_readiness.audit --allow-open --json",
    "mix mob.node.local_readiness.audit --allow-open --json --out <path>",
    "mix mob.node.local_readiness.audit --allow-open --out tmp/ci-local-readiness.json",
    "mix mob.node.local_full_resolution.evidence --json --out <path>",
    "mix mob.node.local_full_resolution.transport_review --template --out <path>",
    "mix mob.node.local_full_resolution.transport_review --input <path> --json --out <path>",
    "mix mob.node.local_inbox.ux_validation_plan --json --out <path>",
    "mix mob.node.local_inbox.ux_evidence --json --out <path>",
    "mix mob.node.local_inbox.ux_review --template --out <path>",
    "mix mob.node.local_inbox.ux_review --input <path> --json --out <path>",
    "mix mob.node.local_ios_parity.evidence --json --out <path>",
    "mix mob.node.local_ios_parity.hardware_review --template --out <path>",
    "mix mob.node.local_ios_parity.hardware_review --input <path> --json --out <path>",
    "mix mob.node.local_known_good_transport.review --template --out <path>",
    "mix mob.node.local_known_good_transport.review --input <path> --json --out <path>",
    "mix mob.node.local_lifecycle.validation_plan --json --out <path>",
    "mix mob.node.local_lifecycle.evidence --json --out <path>",
    "mix mob.node.local_lifecycle.hardware_review --template --out <path>",
    "mix mob.node.local_lifecycle.hardware_review --input <path> --json --out <path>",
    "mix mob.node.local_multi_hop_hardware.evidence --json --out <path>",
    "mix mob.node.local_multi_hop_hardware.review --template --out <path>",
    "mix mob.node.local_multi_hop_hardware.review --input <path> --json --out <path>",
    "mix mob.node.local_persistence.lifecycle_plan --json --out <path>",
    "mix mob.node.local_persistence.evidence --json --out <path>",
    "mix mob.node.local_persistence.production_review --template --out <path>",
    "mix mob.node.local_persistence.production_review --input <path> --json --out <path>",
    "mix mob.node.local_release.artifact_bundle --json --out <path>",
    "mix mob.node.local_release.candidate_review --template --out <path>",
    "mix mob.node.local_release.candidate_review --input <path> --json --out <path>",
    "mix mob.node.local_release.manifest --json --out <path>",
    "mix mob.node.local_release.manifest --json --out tmp/ci-local-release.json",
    "mix mob.node.local_release.recent_evidence --json --out <path>",
    "mix mob.node.local_routing.validation_plan --json --out <path>",
    "mix mob.node.local_routing.evidence --json --out <path>",
    "mix mob.node.local_routing.production_review --template --out <path>",
    "mix mob.node.local_routing.production_review --input <path> --json --out <path>",
    "mix mob.node.local_security.validation_plan --json --out <path>",
    "mix mob.node.local_security.evidence --json --out <path>",
    "mix mob.node.local_security.release_review --template --out <path>",
    "mix mob.node.local_security.release_review --input <path> --json --out <path>",
    "mix format --check-formatted",
    "git diff --check"
  ]

  @spec snapshot() :: map()
  def snapshot do
    release = LocalReleaseCriteria.snapshot()
    readiness = LocalProjectReadiness.snapshot()

    %{
      manifest_version: 1,
      mode: :advertisement_only_local_mesh,
      release_boundary: :validated_advert_only_local_mode,
      whole_project_complete?: false,
      releasable_with_limitations?: release.releasable_with_limitations?,
      release_criteria: criteria_summary(release),
      project_readiness: readiness_summary(readiness),
      completion_audit: completion_summary(LocalProjectCompletionAudit.snapshot()),
      full_resolution_evidence: LocalFullMessageResolutionEvidenceManifest.snapshot(),
      ux_evidence: LocalInboxUxEvidenceManifest.snapshot(),
      ios_parity_evidence: LocalIOSParityEvidenceManifest.snapshot(),
      lifecycle_evidence: LocalLifecycleEvidenceManifest.snapshot(),
      multi_hop_hardware_evidence: LocalMultiHopHardwareEvidenceManifest.snapshot(),
      persistence_evidence: LocalPersistenceEvidenceManifest.snapshot(),
      routing_evidence: LocalRoutingEvidenceManifest.snapshot(),
      hardware_evidence: LocalReleaseEvidenceManifest.snapshot(),
      security_evidence: LocalSecurityEvidenceManifest.snapshot(),
      operator_capture_plan: LocalReleaseOperatorCapturePlan.snapshot(),
      artifact_bundle: LocalReleaseArtifactBundle.snapshot(),
      policy_gates: policy_gates(),
      required_commands: @required_commands,
      required_artifacts: required_artifacts(),
      release_wording: release_wording(),
      notes: [
        "This manifest is for the constrained advert-only local mode, not whole-project completion.",
        "Readiness blockers remain authoritative for full message resolution, known-good transport, and multi-hop hardware proof.",
        "Release artifacts must not claim trusted delivery, routed delivery, background behavior, or iOS parity."
      ]
    }
  end

  defp completion_summary(audit) do
    %{
      audit_version: audit.audit_version,
      objective: audit.objective,
      current_validated_mode: audit.current_validated_mode,
      whole_project_complete?: audit.whole_project_complete?,
      completion_claim_allowed?: audit.completion_claim_allowed?,
      open_item_count: audit.open_item_count,
      blocked_item_count: audit.blocked_item_count,
      partial_item_count: audit.partial_item_count,
      not_started_item_count: audit.not_started_item_count,
      items: audit.items,
      checklist: audit.checklist,
      deliverables: audit.deliverables,
      prompt_artifact_checklist: audit.prompt_artifact_checklist,
      blocker_matrix: audit.blocker_matrix,
      review_template_coverage: audit.review_template_coverage,
      notes: audit.notes
    }
  end

  @spec json_snapshot() :: map()
  def json_snapshot do
    snapshot()
    |> JSON.encode!()
    |> JSON.decode!()
  end

  defp criteria_summary(release) do
    %{
      satisfied_count: release.satisfied_count,
      limited_count: release.limited_count,
      blocked_count: release.blocked_count,
      criteria: Enum.map(release.criteria, &criterion/1),
      notes: release.notes
    }
  end

  defp criterion(criterion) do
    %{
      id: criterion.id,
      status: criterion.status,
      evidence: criterion.evidence,
      limitations: criterion.limitations,
      notes: criterion.notes
    }
  end

  defp readiness_summary(readiness) do
    %{
      open_item_count: readiness.open_item_count,
      blocked_item_count: readiness.blocked_item_count,
      partial_item_count: readiness.partial_item_count,
      not_started_item_count: readiness.not_started_item_count,
      open_items: Enum.map(readiness.open_items, &readiness_item/1),
      notes: readiness.notes
    }
  end

  defp readiness_item(item) do
    %{
      id: item.id,
      status: item.status,
      current_evidence: item.current_evidence,
      remaining_work: item.remaining_work,
      notes: item.notes
    }
  end

  defp policy_gates do
    lifecycle = LocalLifecyclePolicy.snapshot()
    ios = LocalIOSParityPolicy.snapshot()
    routing = LocalRoutingPolicy.snapshot()

    %{
      trust: trust_gate(),
      routing: %{
        routing_claims_allowed?: routing.routing_claims_allowed?,
        allowed_count: routing.allowed_count,
        simulation_only_count: routing.simulation_only_count,
        blocked_count: routing.blocked_count
      },
      lifecycle: %{
        background_claims_allowed?: lifecycle.background_claims_allowed?,
        restart_claims_allowed?: lifecycle.restart_claims_allowed?,
        allowed_count: lifecycle.allowed_count,
        blocked_count: lifecycle.blocked_count
      },
      ios_parity: %{
        ios_participation_claims_allowed?: ios.ios_participation_claims_allowed?,
        contract_only_count: ios.contract_only_count,
        blocked_count: ios.blocked_count
      }
    }
  end

  defp trust_gate do
    empty_trust = LocalTrustPolicy.snapshot(%{trust_evidence: []})

    %{
      delivery_claims_allowed?: false,
      trusted_message_count: empty_trust.trusted_message_count,
      untrusted_count: empty_trust.untrusted_count,
      applies_to_current_observations?: true,
      note:
        "Any observed item remains untrusted unless future authenticated identity, authorship, replay protection, and trust transition evidence exists."
    }
  end

  defp required_artifacts do
    [
      %{
        id: :readiness_manifest,
        command: "mix mob.node.local_readiness.audit --allow-open --json --out <path>",
        purpose: "Archive open whole-project blockers and partial items."
      },
      %{
        id: :completion_audit_manifest,
        command: "mix mob.node.local_release.manifest --json --out <path>",
        purpose: "Archive the whole-project completion claim gate and every open blocker."
      },
      %{
        id: :completion_audit_standalone,
        command: "mix mob.node.local_completion.audit --allow-open --json --out <path>",
        purpose: "Archive the whole-project completion claim gate as a standalone artifact."
      },
      %{
        id: :completion_audit_plain_text_review,
        command:
          "mix mob.node.local_completion.audit --allow-open | tee tmp/local-completion-audit.txt",
        purpose:
          "Archive the plain-text completion audit output so OPEN_ITEMS and OPEN_ITEM lines are reviewable without opening JSON."
      },
      %{
        id: :completion_blocker_matrix,
        command: "mix mob.node.local_completion.blocker_matrix --json --out <path>",
        purpose:
          "Archive blocker categories for remaining hardware, transport, product, implementation, security, and release-evidence work."
      },
      %{
        id: :focused_remaining_items_audit,
        command: "mix mob.node.remaining_items.audit --json --out <path>",
        purpose:
          "Archive the focused four-row remaining-items objective, including the two completed rows and two externally blocked rows."
      },
      %{
        id: :focused_remaining_items_plain_text_review,
        command: "mix mob.node.remaining_items.audit | tee <path>",
        purpose:
          "Archive the focused four-row remaining-items checklist and blocked completion decision as plain text."
      },
      %{
        id: :direct_full_mx_aux_validation_checklist,
        command:
          "Archive artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/android-aux-full-mx-ios-observe-rerun/aux-validation-checklist.md",
        purpose:
          "Archive the exact platform callback, canonical parse, MB fallback, and metadata evidence required before direct full-MX AUX interop can be marked complete."
      },
      %{
        id: :upstream_patch_maintainer_handoff,
        command:
          "Archive artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/upstream-pr-recheck-1358/maintainer-handoff.md",
        purpose:
          "Archive the upstream maintainer merge/release actions and MeshX post-merge migration gates required before downstream patches can be removed."
      },
      %{
        id: :upstream_patch_migration_progress,
        command:
          "Archive artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/upstream-pr-recheck-1358/upstream-migration-progress.json",
        purpose:
          "Archive the machine-readable upstream migration progress gate, including satisfied pre-merge criteria and missing merge/release/migration criteria."
      },
      %{
        id: :ux_validation_plan,
        command: "mix mob.node.local_inbox.ux_validation_plan --json --out <path>",
        purpose:
          "Archive the Nearby Messages on-device UX validation checklist before target-device evidence review."
      },
      %{
        id: :ux_evidence_manifest,
        command: "mix mob.node.local_inbox.ux_evidence --json --out <path>",
        purpose:
          "Archive Nearby Messages surface coverage, control summaries, blocked-claim copy, and open on-device UX validation gates."
      },
      %{
        id: :ux_decision_scenario_plan,
        command: "mix mob.node.local_inbox.ux_evidence --json --out <path>",
        source: "LocalInboxUxDecisionScenarioPlan",
        purpose:
          "Archive Nearby Messages UX decision scenarios before any production UX wording changes."
      },
      %{
        id: :ux_target_device_scenario_plan,
        command: "mix mob.node.local_inbox.ux_evidence --json --out <path>",
        source: "LocalInboxUxTargetDeviceScenarioPlan",
        purpose:
          "Archive concrete Nearby Messages target-device UX scenarios for state rows, filters, sorting, selected details, copy review, and visual density."
      },
      %{
        id: :ux_evidence_template,
        command: "mix mob.node.local_inbox.ux_review --template --out <path>",
        purpose:
          "Generate incomplete operator metadata scaffold for target-device UX attachments."
      },
      %{
        id: :ux_evidence_review,
        command: "mix mob.node.local_inbox.ux_review --input <path> --json --out <path>",
        purpose:
          "Review operator-supplied target-device, state, interaction, selected-detail, copy, and density evidence metadata."
      },
      %{
        id: :full_message_resolution_evidence_manifest,
        command: "mix mob.node.local_full_resolution.evidence --json --out <path>",
        purpose:
          "Archive beacon resolution contracts, offline fetch evidence, and blocked real transport gates."
      },
      %{
        id: :full_resolution_transport_evidence_template,
        command: "mix mob.node.local_full_resolution.transport_review --template --out <path>",
        purpose:
          "Generate incomplete operator metadata scaffold for full-message-resolution transport evidence."
      },
      %{
        id: :full_resolution_transport_evidence_review,
        command:
          "mix mob.node.local_full_resolution.transport_review --input <path> --json --out <path>",
        purpose:
          "Review operator-supplied full-resolution transport metadata before any real beacon resolution wording changes."
      },
      %{
        id: :known_good_transport_evidence_template,
        command: "mix mob.node.local_known_good_transport.review --template --out <path>",
        purpose:
          "Generate incomplete operator metadata scaffold for known-good constrained fetch transport evidence."
      },
      %{
        id: :known_good_transport_evidence_review,
        command:
          "mix mob.node.local_known_good_transport.review --input <path> --json --out <path>",
        purpose:
          "Review operator-supplied transport decision, hardware-pair interop, tiny read/write, known-bad separation, and release-linkage metadata before any known-good transport wording changes."
      },
      %{
        id: :lifecycle_validation_plan,
        command: "mix mob.node.local_lifecycle.validation_plan --json --out <path>",
        purpose:
          "Archive the mobile BLE lifecycle hardware validation checklist before operator evidence review."
      },
      %{
        id: :lifecycle_evidence_manifest,
        command: "mix mob.node.local_lifecycle.evidence --json --out <path>",
        purpose:
          "Archive foreground/manual lifecycle evidence, open hardware gates, and blocked background claims."
      },
      %{
        id: :lifecycle_decision_scenario_plan,
        command: "mix mob.node.local_lifecycle.evidence --json --out <path>",
        source: "LocalLifecycleDecisionScenarioPlan",
        purpose:
          "Archive keep_foreground_manual and enable_background_lifecycle decision scenarios before any lifecycle wording changes."
      },
      %{
        id: :lifecycle_hardware_evidence_template,
        command: "mix mob.node.local_lifecycle.hardware_review --template --out <path>",
        purpose:
          "Generate incomplete operator metadata scaffold for mobile lifecycle hardware evidence."
      },
      %{
        id: :lifecycle_hardware_evidence_review,
        command:
          "mix mob.node.local_lifecycle.hardware_review --input <path> --json --out <path>",
        purpose:
          "Review operator-supplied mobile lifecycle hardware metadata before any foreground-service, background BLE, restart, retry, or background gossip wording changes."
      },
      %{
        id: :multi_hop_hardware_evidence_manifest,
        command: "mix mob.node.local_multi_hop_hardware.evidence --json --out <path>",
        purpose:
          "Archive replay evidence, one-hop hardware scope, and blocked physical multi-hop gates."
      },
      %{
        id: :multi_hop_hardware_evidence_template,
        command: "mix mob.node.local_multi_hop_hardware.review --template --out <path>",
        purpose:
          "Generate incomplete operator metadata scaffold for physical multi-hop hardware evidence."
      },
      %{
        id: :multi_hop_hardware_evidence_review,
        command:
          "mix mob.node.local_multi_hop_hardware.review --input <path> --json --out <path>",
        purpose:
          "Review operator-supplied origin, relay, observer, replay, TTL/suppression, one-hop negative, and release-linkage metadata before any physical multi-hop wording changes."
      },
      %{
        id: :ios_parity_evidence_manifest,
        command: "mix mob.node.local_ios_parity.evidence --json --out <path>",
        purpose:
          "Archive partial iOS hardware evidence, open hardware gates, and blocked iOS parity claims."
      },
      %{
        id: :ios_parity_decision_scenario_plan,
        command: "mix mob.node.local_ios_parity.evidence --json --out <path>",
        source: "LocalIOSParityDecisionScenarioPlan",
        purpose:
          "Archive keep_ios_contract_only and enable_ios_advert_only_participation decision scenarios before any iOS parity wording changes."
      },
      %{
        id: :ios_parity_operator_capture_plan,
        command: "mix mob.node.local_ios_parity.evidence --json --out <path>",
        source: "LocalIOSParityOperatorCapturePlan",
        purpose:
          "Archive the iOS parity operator capture checklist for target devices, canonical ingress, legacy beacon observe/gossip, full-envelope capability, replay fixture, background boundary, and negative evidence."
      },
      %{
        id: :ios_parity_hardware_evidence_template,
        command: "mix mob.node.local_ios_parity.hardware_review --template --out <path>",
        purpose:
          "Generate incomplete operator metadata scaffold for iOS advert-only hardware evidence."
      },
      %{
        id: :ios_parity_hardware_evidence_review,
        command:
          "mix mob.node.local_ios_parity.hardware_review --input <path> --json --out <path>",
        purpose:
          "Review operator-supplied iOS device, canonical ingress, beacon observe/gossip, capability, replay, background-boundary, and negative-claim metadata before any iOS parity wording changes."
      },
      %{
        id: :production_persistence_lifecycle_plan,
        command: "mix mob.node.local_persistence.lifecycle_plan --json --out <path>",
        purpose:
          "Archive the production-default persistence lifecycle checklist before operator evidence review."
      },
      %{
        id: :persistence_evidence_manifest,
        command: "mix mob.node.local_persistence.evidence --json --out <path>",
        purpose:
          "Archive opt-in persistence evidence, memory-only default policy, and blocked production lifecycle gates."
      },
      %{
        id: :production_persistence_default_decision_scenario_plan,
        command: "mix mob.node.local_persistence.evidence --json --out <path>",
        source: "LocalPersistenceDefaultDecisionScenarioPlan",
        purpose:
          "Archive keep_memory_only_default and promote_durable_default decision scenarios before any default-persistence wording changes."
      },
      %{
        id: :production_persistence_evidence_template,
        command: "mix mob.node.local_persistence.production_review --template --out <path>",
        purpose:
          "Generate incomplete operator metadata scaffold for production-default persistence lifecycle evidence."
      },
      %{
        id: :production_persistence_evidence_review,
        command:
          "mix mob.node.local_persistence.production_review --input <path> --json --out <path>",
        purpose:
          "Review operator-supplied production-default persistence lifecycle metadata before any default-persistence wording changes."
      },
      %{
        id: :routing_validation_plan,
        command: "mix mob.node.local_routing.validation_plan --json --out <path>",
        purpose:
          "Archive the production routing hardware validation checklist before operator evidence review."
      },
      %{
        id: :routing_evidence_manifest,
        command: "mix mob.node.local_routing.evidence --json --out <path>",
        purpose:
          "Archive route-candidate evidence, non-routing policy, hardware gates, and blocked routing claims."
      },
      %{
        id: :routing_decision_scenario_plan,
        command: "mix mob.node.local_routing.evidence --json --out <path>",
        source: "LocalRoutingDecisionScenarioPlan",
        purpose:
          "Archive keep_advert_only_non_routing and enable_production_routing decision scenarios before any routing wording changes."
      },
      %{
        id: :production_routing_evidence_template,
        command: "mix mob.node.local_routing.production_review --template --out <path>",
        purpose:
          "Generate incomplete operator metadata scaffold for production routing validation evidence."
      },
      %{
        id: :production_routing_evidence_review,
        command:
          "mix mob.node.local_routing.production_review --input <path> --json --out <path>",
        purpose:
          "Review operator-supplied production routing evidence metadata before any routing, forwarding, delivery, or multi-hop wording changes."
      },
      %{
        id: :release_manifest,
        command: "mix mob.node.local_release.manifest --json --out <path>",
        purpose: "Archive advert-only release boundary, policy gates, and command checklist."
      },
      %{
        id: :hardware_evidence_manifest,
        command: "mix mob.node.local_release.manifest --json --out <path>",
        purpose:
          "Archive hardware validation gates and open release-candidate evidence requirements."
      },
      %{
        id: :artifact_bundle_checklist,
        command: "mix mob.node.local_release.artifact_bundle --json --out <path>",
        purpose:
          "Archive the release-candidate artifact bundle checklist and open operator attachments."
      },
      %{
        id: :recent_evidence_inventory,
        command: "mix mob.node.local_release.recent_evidence --json --out <path>",
        source: "LocalReleaseRecentEvidenceInventory",
        purpose:
          "Archive recent no-new-hardware evidence slices while keeping completion, delivery, trust, routing, background, iOS parity, and full-resolution claims blocked."
      },
      %{
        id: :release_operator_capture_plan,
        command: "mix mob.node.local_release.manifest --json --out <path>",
        source: "LocalReleaseOperatorCapturePlan",
        purpose:
          "Archive the release-candidate operator capture checklist for manifests, objective reviews, hardware attachments, operator notes, and final release-candidate review."
      },
      %{
        id: :release_candidate_evidence_template,
        command: "mix mob.node.local_release.candidate_review --template --out <path>",
        purpose:
          "Generate incomplete operator metadata scaffold for release-candidate hardware attachments and wording review."
      },
      %{
        id: :release_candidate_evidence_review,
        command: "mix mob.node.local_release.candidate_review --input <path> --json --out <path>",
        purpose:
          "Review supplied hardware attachment metadata and operator wording before accepting release-candidate notes."
      },
      %{
        id: :security_validation_plan,
        command: "mix mob.node.local_security.validation_plan --json --out <path>",
        purpose:
          "Archive the authenticated local message security validation checklist before release evidence review."
      },
      %{
        id: :security_evidence_manifest,
        command: "mix mob.node.local_security.evidence --json --out <path>",
        purpose:
          "Archive local security gates, fixture evidence, blocked claims, and release review state."
      },
      %{
        id: :security_decision_scenario_plan,
        command: "mix mob.node.local_security.evidence --json --out <path>",
        source: "LocalSecurityDecisionScenarioPlan",
        purpose:
          "Archive keep_unsigned_local_observation and enable_authenticated_local_trust decision scenarios before any authenticated or trusted wording changes."
      },
      %{
        id: :security_operator_capture_plan,
        command: "mix mob.node.local_security.evidence --json --out <path>",
        source: "LocalSecurityOperatorCapturePlan",
        purpose:
          "Archive the security operator capture checklist for peer/key enrollment, authorship, replay lifecycle, trust lifecycle, canonical replay, beacon authentication, release evidence, and negative claim review."
      },
      %{
        id: :security_release_evidence_template,
        command: "mix mob.node.local_security.release_review --template --out <path>",
        purpose:
          "Generate incomplete operator metadata scaffold for local security release evidence."
      },
      %{
        id: :security_release_evidence_review,
        command: "mix mob.node.local_security.release_review --input <path> --json --out <path>",
        purpose:
          "Review operator-supplied security evidence metadata before any authenticated or trusted wording changes."
      },
      %{
        id: :advert_gossip_audit,
        command:
          "mix mob.node.advert_gossip.audit apps/mob_node/test/fixtures/advert_gossip_scenarios",
        purpose: "Prove replay advert gossip scenarios remain deterministic."
      }
    ]
  end

  defp release_wording do
    %{
      allowed: [
        "MeshX can show messages seen nearby from passive BLE advertisement observations.",
        "Legacy beacon refs are unresolved pointers.",
        "Full-envelope adverts are shown only when capability-proven and canonical envelope validation passes."
      ],
      blocked: [
        "Guaranteed delivery.",
        "Trusted/authenticated message delivery.",
        "Routed or multi-hop hardware delivery.",
        "Background mobile operation.",
        "iOS advert-only participation."
      ]
    }
  end
end
