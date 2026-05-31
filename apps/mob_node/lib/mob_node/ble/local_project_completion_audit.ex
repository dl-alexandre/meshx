defmodule Mob.Node.BLE.LocalProjectCompletionAudit do
  @moduledoc """
  Whole-project completion audit for the local BLE mesh work.

  This module maps the project objective to current artifacts, required
  evidence, and still-open blockers. It is a claim gate: it records why
  whole-project completion is not currently allowed. It does not inspect
  hardware, scan, advertise, fetch, route, persist, ACK, retry, encrypt,
  or run background work.
  """

  alias Mob.Node.BLE.{LocalProjectCompletionBlockerMatrix, LocalProjectReadiness}

  @objective_specs [
    %{
      objective_id: :full_message_resolution,
      title: "Resolve a legacy beacon into a full MessageEnvelope",
      readiness_id: :full_message_resolution,
      required_artifacts: [
        "BeaconRef parser and resolver contract.",
        "BeaconFetchRequest contract and fetch planning pipeline.",
        "Fake/offline fetch integration test.",
        "LocalFetchTransportValidationPlan gate checklist for candidate transport, standalone interop, constrained fetch, canonical replay, negative failures, and release artifacts.",
        "LocalFullMessageResolutionEvidenceManifest archiveable resolver/fetch contract evidence and blocked real transport gates.",
        "LocalFullMessageResolutionEvidenceReview archiveable operator metadata review for real transport evidence.",
        "LocalKnownGoodTransportEvidenceReview archiveable operator metadata review for the known-good transport prerequisite.",
        "Real constrained transport proof retrieving and parsing one full MessageEnvelope."
      ],
      missing_evidence: [
        "Evidence satisfying LocalFetchTransportValidationPlan candidate transport, standalone interop, constrained fetch, canonical replay, negative failure, and release artifact gates.",
        "Real transport proof that retrieves a full MessageEnvelope from a legacy beacon ref.",
        "Hardware logs showing the retrieved envelope parses through canonical replay."
      ],
      notes: [
        "Beacon refs remain unresolved pointers until real fetch evidence exists."
      ]
    },
    %{
      objective_id: :known_good_transport_validation,
      title: "Validate a known-good constrained fetch transport",
      readiness_id: :known_good_transport_validation,
      required_artifacts: [
        "Standalone interop harness proof on a known-good device pair.",
        "LocalFetchTransportValidationPlan gate checklist for selecting and proving the constrained fetch transport.",
        "LocalFullMessageResolutionEvidenceManifest archiveable known-good transport blocker evidence.",
        "LocalKnownGoodTransportEvidenceReview archiveable operator metadata review for known-good transport selection and standalone interop.",
        "Transport decision ledger entry for the validated path.",
        "Constrained fetch proof on the same or better hardware pair."
      ],
      missing_evidence: [
        "Evidence satisfying LocalFetchTransportValidationPlan candidate transport and standalone interop gates.",
        "Known-good GATT pair or alternate constrained fetch transport.",
        "Connect, discovery, tiny read/write, and full-envelope fetch logs."
      ],
      notes: [
        "SM-T577U/SM-T390 GATT status 133 remains a transport/platform blocker, not a protocol success."
      ]
    },
    %{
      objective_id: :multi_hop_hardware_proof,
      title: "Prove multi-hop behavior on physical participants",
      readiness_id: :multi_hop_hardware_proof,
      required_artifacts: [
        "Replay topology fixtures and advert gossip audit.",
        "LocalAdvertGossipHardwareValidationPlan gate checklist for three-role device matrix, origin/relay/observer capture, replay normalization, TTL/suppression, one-hop negative review, and release artifacts.",
        "LocalMultiHopHardwareEvidenceManifest archiveable replay-vs-hardware evidence and blocked physical multi-hop gates.",
        "LocalMultiHopHardwareEvidenceReview archiveable operator metadata review for physical multi-hop hardware evidence.",
        "Three or more physical participants or equivalent controlled physical rig.",
        "Origin, relay, and observer logs proving bounded propagation."
      ],
      missing_evidence: [
        "Evidence satisfying LocalAdvertGossipHardwareValidationPlan three-role device matrix, origin/relay/observer capture, replay fixture, TTL/suppression, one-hop negative, and release artifact gates.",
        "Physical multi-hop hardware capture with origin, relay, and observer roles.",
        "Release evidence manifest entries pointing to the captured logs and summaries."
      ],
      notes: [
        "Replay multi-hop proof is deterministic policy evidence; it is not hardware proof."
      ]
    },
    %{
      objective_id: :product_ux,
      title: "Ship a production Nearby Messages surface",
      readiness_id: :product_ux,
      required_artifacts: [
        "Local inbox view/query/presenter/product/native surface models.",
        "Nearby Messages summary line and state-specific empty copy.",
        "Centralized state copy for full messages, unresolved refs, gossiped refs, and stale refs.",
        "LocalInboxUxAcceptance gates for state coverage, control summaries, sorting, details, blocked-claim copy, blocked-claim warnings, and on-device validation.",
        "LocalInboxUxValidationPlan gate checklist for target devices, evidence_kind classified screenshots/operator notes, interactions, selected detail limitation_copy, next_action_copy, blocked_claim_copy, and visual density.",
        "LocalInboxUxOperatorCapturePlan target-device capture checklist for states, interactions, selected details, copy review, and visual density.",
        "LocalInboxUxTargetDeviceScenarioPlan concrete target-device UX scenario matrix for state rows, filters, sorting, selected details, copy review, and visual density.",
        "LocalInboxUxDecisionScenarioPlan decision scenario matrix for keeping pure surface evidence or promoting production UX.",
        "LocalInboxUxEvidenceManifest archiveable UX surface coverage, evidence_kind classified selected detail evidence, control summaries, limitation_copy, next_action_copy, blocked_claim_copy, and open validation gates.",
        "LocalInboxUxEvidenceReview archiveable operator metadata review for on-device UX attachments with coverage_summary counts.",
        "Native interactive controls for filters, sorting, rows, and detail panel.",
        "Operator-visible wording that blocks overclaims.",
        "On-device UX validation for production release."
      ],
      missing_evidence: [
        "Satisfied LocalInboxUxAcceptance on-device validation gate with attached evidence.",
        "Evidence satisfying LocalInboxUxValidationPlan target device, state coverage, interaction, selected detail limitation_copy, next_action_copy, blocked_claim_copy, and visual density gates with evidence_kind classification.",
        "Ready LocalInboxUxEvidenceReview output for supplied target-device UX attachments.",
        "On-device UX validation for unresolved refs, full messages, trust state, and blockers.",
        "Production visual-density review."
      ],
      notes: [
        "The Mob screen now uses the native surface model, centralized state copy, control summaries, selected detail evidence, coverage-summary review output, selected-detail limitation_copy, next_action_copy, blocked_claim_copy, and pure UX acceptance gates, but production UX still needs device validation."
      ]
    },
    %{
      objective_id: :persistence,
      title: "Decide and validate local inbox persistence lifecycle",
      readiness_id: :persistence,
      required_artifacts: [
        "Persistence policy and profile.",
        "Persistence lifecycle decision_outcome keep_memory_only_default for the current validated mode.",
        "LocalPersistenceAcceptance gate for durable policy, store boundary, restore, operator controls, negative validation, and default lifecycle blockers.",
        "LocalPersistenceProductionLifecyclePlan gate checklist for default decision, migrations, scheduled cleanup, background-safe writer, on-device restore, and release artifact evidence.",
        "LocalPersistenceOperatorCapturePlan operator capture checklist for default decision, migration, cleanup, writer, restore, and release evidence.",
        "LocalPersistenceDefaultDecisionScenarioPlan decision scenario matrix for keep_memory_only_default and promote_durable_default outcomes.",
        "LocalPersistenceEvidenceManifest archiveable opt-in persistence evidence and blocked production-default lifecycle gates.",
        "LocalPersistenceProductionEvidenceReview archiveable operator metadata review for production-default persistence evidence with default_lifecycle_decision decision_outcome.",
        "CubDB store boundary, list, prune, save, load, and delete behavior.",
        "Current persistence negative validation matrix plus future implementation-backed production fixtures.",
        "Default lifecycle decision_outcome, migrations, cleanup, and background-safe write policy if required."
      ],
      missing_evidence: [
        "Satisfied LocalPersistenceAcceptance production_default_lifecycle gate if persistence becomes default.",
        "Operator/release evidence for the selected decision_outcome before changing persistence claims.",
        "Evidence satisfying LocalPersistenceProductionLifecyclePlan default decision, migration, cleanup, background-safe writer, on-device restore, and release artifact gates.",
        "Ready LocalPersistenceProductionEvidenceReview output for supplied production persistence lifecycle metadata, including default_lifecycle_decision decision_outcome.",
        "Migration, scheduled cleanup, background-safe write, and on-device restore validation if persistence is production-default.",
        "Implementation-backed negative fixtures proving opt-in snapshots, persisted beacon refs, manual prune, foreground save hooks, and durable read models cannot satisfy default persistence or delivery claims."
      ],
      notes: [
        "Durable snapshots and explicit operator controls exist; lifecycle policy and negative validation keep default app sessions memory-only unless production gates pass."
      ]
    },
    %{
      objective_id: :security_identity,
      title: "Add authenticated local identity and trust transitions",
      readiness_id: :security_identity,
      required_artifacts: [
        "Authenticated peer identity.",
        "Security decision_outcome keep_unsigned_local_observation for the current validated advertisement-only mode.",
        "LocalSecurityPeerEnrollment operator-supplied peer/key enrollment boundary that rejects passive observations.",
        "LocalSecurityPeerIdentityBinding for supplied peer_id to Ed25519 public key binding.",
        "Authorship proof for envelopes and beacon refs.",
        "Replay protection.",
        "LocalSecurityReplayProtection bounded in-memory replay guard for verified full-envelope proofs.",
        "LocalSecurityReplayLifecyclePolicy memory-only replay lifecycle boundary.",
        "LocalSecurityReplayLifecycleValidation executable duplicate, pruning, restart, expiry, and beacon-ref replay lifecycle matrix.",
        "LocalSecurityAuthorshipProof verification boundary for full MessageEnvelope authorship.",
        "LocalSecurityTrustedMessageDecision full-envelope trust decision boundary.",
        "LocalSecurityCanonicalReplayDecision canonical ReceivedMessage replay integration for trusted-message decisions.",
        "LocalSecurityOperatorTrustPolicy explicit peer_id/key_id scoped trust policy boundary.",
        "LocalSecurityTrustLifecyclePlan persistent trust lifecycle contract for key enrollment, storage, rotation, revocation, replay state, and release audit export.",
        "LocalSecurityTrustLifecycleValidation executable supplied-policy key rotation and revocation fail-closed matrix.",
        "LocalSecurityIdentityValidationPlan gate checklist for peer enrollment, authorship fixtures, replay lifecycle, trust lifecycle, canonical replay, beacon authentication, release evidence, and negative claim review.",
        "LocalSecurityFixtureAudit fixture inventory for every LocalSecurityIdentityValidationPlan gate.",
        "LocalSecurityDecisionScenarioPlan decision scenario matrix for keep_unsigned_local_observation and enable_authenticated_local_trust outcomes.",
        "LocalSecurityOperatorCapturePlan operator capture checklist for peer/key enrollment, authorship, replay lifecycle, trust lifecycle, canonical replay, beacon authentication, release evidence, and negative claim review.",
        "LocalSecurityReleaseEvidenceReview operator-reviewed security evidence package checklist.",
        "LocalSecurityEvidenceManifest archiveable security evidence manifest and Mix task.",
        "LocalSecurityBeaconAuthentication pointer-authentication boundary for resolved trusted beacon refs.",
        "LocalSecurityCryptoNegativeValidation executable tamper, replay, key mismatch, blocked/revoked policy, and beacon-ref promotion negative cases.",
        "Trust state model and crypto-backed transition policy.",
        "LocalSecurityAcceptance gates for current trust policy, future security contract, trust model, negative validation, authenticated identity, authorship, replay protection, and beacon authentication.",
        "Current negative validation matrix plus future crypto-backed positive and negative fixtures."
      ],
      missing_evidence: [
        "Operator/release evidence for the selected security decision_outcome before trusted-message claims change.",
        "Satisfied LocalSecurityAcceptance authenticated identity, message authorship, replay protection, and beacon authentication gates.",
        "Evidence satisfying LocalSecurityIdentityValidationPlan peer enrollment, authorship, replay lifecycle, trust lifecycle, canonical replay, beacon authentication, release evidence, and negative claim review gates.",
        "Canonical replay and full-envelope resolution integration for LocalSecurityBeaconAuthentication.",
        "Implementation evidence for LocalSecurityTrustLifecyclePlan gates.",
        "Expanded positive and negative fixtures for persistent trust lifecycle, key rotation, trust revocation, and hash-only beacon promotion."
      ],
      notes: [
        "Current hashes are references, not proof of authorship; current trust model and negative validation block over-promotion."
      ]
    },
    %{
      objective_id: :routing,
      title: "Implement production routing if MeshX needs live delivery",
      readiness_id: :routing,
      required_artifacts: [
        "Routing decision_outcome keep_advert_only_non_routing for the current validated mode.",
        "Local route candidate table and future production route selection.",
        "LocalRoutingAcceptance gates for observation policy, candidate table, future routing contract, negative validation, production route table, route selection, forwarding service, delivery semantics, and multi-hop hardware.",
        "LocalRoutingHardwareValidationPlan gate checklist for route table, deterministic selection, forwarding, delivery semantics, multi-hop hardware rig, TTL/loop evidence, release artifacts, and negative claim review.",
        "LocalRoutingOperatorCapturePlan operator capture checklist for route table, route selection, forwarding, delivery semantics, multi-hop rig, TTL/loop, release, and negative evidence.",
        "LocalRoutingDecisionScenarioPlan decision scenario matrix for keep_advert_only_non_routing and enable_production_routing outcomes.",
        "LocalRoutingEvidenceManifest archiveable route-candidate evidence and blocked routing gates.",
        "LocalRoutingProductionEvidenceReview archiveable operator metadata review for production routing evidence.",
        "Forwarding service and delivery semantics.",
        "ACK/retry policy if delivery claims require it.",
        "Loop, TTL, unreachable, and stale-route validation.",
        "Current routing negative validation matrix plus future implementation-backed negative fixtures."
      ],
      missing_evidence: [
        "Production routing implementation beyond local route candidates.",
        "Operator/release evidence for the selected routing decision_outcome before changing routing claims.",
        "Satisfied LocalRoutingAcceptance production routing table, route selection, forwarding service, delivery semantics, and multi-hop hardware gates.",
        "Evidence satisfying LocalRoutingHardwareValidationPlan route table, route selection, forwarding, delivery, multi-hop rig, TTL/loop, release artifact, and negative claim review gates.",
        "Ready LocalRoutingProductionEvidenceReview output for supplied production routing evidence metadata.",
        "Hardware proof of bounded route behavior and failure surfaces.",
        "Implementation-backed negative fixtures for stale routes, unreachable next hops, missing ACK/retry policy, replay-only gossip, and one-hop-only hardware evidence."
      ],
      notes: [
        "Current validated behavior is local advertisement observation, pure route candidates, and replay gossip simulation; current negative validation blocks routing overclaims."
      ]
    },
    %{
      objective_id: :background_mobile_lifecycle,
      title: "Validate mobile background and restart lifecycle if required",
      readiness_id: :background_mobile_lifecycle,
      required_artifacts: [
        "Lifecycle decision_outcome keep_foreground_manual for the current validated mode.",
        "Android foreground service implementation and proof if required.",
        "iOS background behavior implementation and proof if required.",
        "Restart, cancellation, throttling, and scheduled retry validation if required.",
        "LocalLifecycleAcceptance gates for foreground/manual profile, lifecycle policy, future lifecycle contract, negative validation, Android foreground service, Android/iOS background BLE, automatic restart, scheduled retry, and background gossip.",
        "LocalLifecycleHardwareValidationPlan gate checklist for target devices, foreground-service backgrounding, Android/iOS background BLE, restart/cancellation, scheduled retry, background gossip, and negative claim review.",
        "LocalLifecycleOperatorCapturePlan operator capture checklist for target devices, foreground service, background BLE, restart, retry, background gossip, and negative evidence.",
        "LocalLifecycleDecisionScenarioPlan decision scenario matrix for keep_foreground_manual and enable_background_lifecycle outcomes.",
        "LocalLifecycleEvidenceManifest archiveable foreground/manual lifecycle evidence and blocked background lifecycle gates.",
        "LocalLifecycleHardwareEvidenceReview archiveable operator metadata review for mobile lifecycle hardware evidence.",
        "Current lifecycle negative validation matrix plus future implementation-backed negative fixtures."
      ],
      missing_evidence: [
        "Background mobile implementation.",
        "Operator/release evidence for the selected lifecycle decision_outcome before changing background lifecycle claims.",
        "Satisfied LocalLifecycleAcceptance Android foreground service, Android/iOS background BLE, automatic restart, scheduled retry, and background gossip gates.",
        "Evidence satisfying LocalLifecycleHardwareValidationPlan target device, app-backgrounding, restart, scheduled retry, background gossip, and negative claim review gates.",
        "Ready LocalLifecycleHardwareEvidenceReview output for supplied mobile lifecycle hardware evidence metadata.",
        "Device logs proving OS lifecycle behavior under app backgrounding and restart.",
        "Implementation-backed negative fixtures for foreground-only behavior, OS throttling, restart cancellation, scheduled retry blocking, and background gossip bounds."
      ],
      notes: [
        "Current BLE validation is foreground/manual harness style; current negative validation blocks lifecycle overclaims."
      ]
    },
    %{
      objective_id: :ios_parity,
      title: "Validate iOS advert-only participation",
      readiness_id: :ios_parity,
      required_artifacts: [
        "iOS advert-only beacon/full-envelope implementation.",
        "iOS hardware evidence normalized through canonical replay.",
        "Parity fixtures or validation ledgers.",
        "LocalIOSParityAcceptance gates for shared canonical contracts, future iOS parity contract, negative validation, canonical ingress, legacy beacon observe/gossip, full-envelope advert, hardware replay fixture, and iOS background BLE.",
        "LocalIOSParityHardwareValidationPlan gate checklist for iOS device matrix, canonical ingress fixture, legacy beacon observe/gossip hardware, full-envelope capability, hardware replay fixture, background boundary, and negative claim review.",
        "LocalIOSAdvertCarrierDecision ledger separating hardware-validated legacy-beacon observe, implemented-unvalidated foreground iOS MB beacon emit, blocked iOS beacon gossip, and PHY-blocked full-MX extended-advert observe.",
        "LocalHardwareValidationGates partial iOS participation entry with Android fetch from iOS MobFetchGattResponder evidence under artifacts/local-ble/2026-05-17-sm-t577u-ipad9/.",
        "LocalIOSParityOperatorCapturePlan operator capture checklist for target devices, canonical ingress, legacy beacon observe/gossip, full-envelope capability, replay fixture, background boundary, and negative evidence.",
        "LocalIOSParityDecisionScenarioPlan decision scenario matrix for keep_ios_contract_only and enable_ios_advert_only_participation outcomes.",
        "LocalIOSParityEvidenceManifest archiveable contract-only iOS evidence and blocked parity gates.",
        "LocalIOSParityHardwareEvidenceReview operator review for iOS device, canonical ingress, beacon observe/gossip, capability, replay, background-boundary, and negative-claim metadata.",
        "Current iOS parity negative validation matrix plus future implementation-backed iOS fixtures."
      ],
      missing_evidence: [
        "Android observer capture and replay-normalized evidence for iOS-origin MB beacon emission before any iOS beacon gossip claim.",
        "Satisfied LocalIOSParityAcceptance legacy beacon gossip, full-envelope advert, hardware replay fixture, and iOS background BLE gates.",
        "Evidence satisfying LocalIOSParityHardwareValidationPlan target device, canonical ingress, legacy beacon observe/gossip, full-envelope capability, hardware replay, background boundary, and negative claim review gates.",
        "iOS device capture proving beacon gossip and any full-envelope direct-advert capability.",
        "Implementation-backed negative fixtures proving bridge shell, Android evidence, missing dispatcher, unproven capability, and missing replay fixtures cannot satisfy iOS parity."
      ],
      notes: [
        "Foreground iOS legacy-beacon observe and Android fetch from iOS responder have hardware evidence; foreground iOS MB beacon emit code exists, but iOS-origin cross-radio gossip proof is still missing and direct full-MX extended advertising remains blocked on tested iOS hardware."
      ]
    },
    %{
      objective_id: :release_hardening,
      title: "Package release-candidate evidence without overclaiming",
      readiness_id: :release_hardening,
      required_artifacts: [
        "Readiness manifest.",
        "Release manifest.",
        "Completion audit manifest.",
        "Hardware evidence manifest.",
        "Release artifact bundle checklist.",
        "Local release artifact bundle task output.",
        "LocalReleaseRecentEvidenceInventory for no-new-hardware evidence traceability.",
        "Advert gossip audit output.",
        "Local release candidate review task output.",
        "LocalReleaseOperatorCapturePlan release-candidate capture checklist for manifests, objective reviews, hardware attachments, operator notes, and final review.",
        "LocalReleaseCandidateEvidenceReview for operator hardware attachments and release-note wording.",
        "Upstream patch migration handoff evidence from docs/upstream_mob_patches.md.",
        "Operator docs and release notes that preserve open blockers."
      ],
      missing_evidence: [
        "Concrete release-candidate artifact bundle with attached hardware logs, summaries, and operator-authored release notes.",
        "Ready LocalReleaseCandidateEvidenceReview or local release candidate review task output for the release candidate.",
        "Merged and released GenericJam/mob_dev#6 and GenericJam/mob_new#5, followed by MeshX dependency migration and post-merge verification before removing downstream patches.",
        "Final release wording review against the completion audit."
      ],
      notes: [
        "The advert-only local mode may be releasable with limitations; the whole project is still open, and upstream patch migration remains incomplete until maintainer merge/release and MeshX dependency migration finish."
      ]
    }
  ]

  @required_commands [
    "mix test",
    "mix mob.node.advert_gossip.audit apps/mob_node/test/fixtures/advert_gossip_scenarios",
    "mix mob.node.local_completion.audit --allow-open",
    "mix mob.node.local_completion.audit --allow-open | tee tmp/local-completion-audit.txt",
    "mix mob.node.local_completion.audit --allow-open --json --out <path>",
    "mix mob.node.local_completion.blocker_matrix --json --out <path>",
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
    "mix mob.node.local_readiness.audit --allow-open --json",
    "mix mob.node.local_release.artifact_bundle --json --out <path>",
    "mix mob.node.local_release.candidate_review --template --out <path>",
    "mix mob.node.local_release.candidate_review --input <path> --json --out <path>",
    "mix mob.node.local_release.manifest --json --out <path>",
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

  @review_template_commands [
    %{
      review_id: :full_resolution_transport,
      template_command:
        "mix mob.node.local_full_resolution.transport_review --template --out <path>",
      review_command:
        "mix mob.node.local_full_resolution.transport_review --input <path> --json --out <path>"
    },
    %{
      review_id: :nearby_messages_ux,
      template_command: "mix mob.node.local_inbox.ux_review --template --out <path>",
      review_command: "mix mob.node.local_inbox.ux_review --input <path> --json --out <path>"
    },
    %{
      review_id: :ios_parity_hardware,
      template_command: "mix mob.node.local_ios_parity.hardware_review --template --out <path>",
      review_command:
        "mix mob.node.local_ios_parity.hardware_review --input <path> --json --out <path>"
    },
    %{
      review_id: :known_good_transport,
      template_command: "mix mob.node.local_known_good_transport.review --template --out <path>",
      review_command:
        "mix mob.node.local_known_good_transport.review --input <path> --json --out <path>"
    },
    %{
      review_id: :mobile_lifecycle_hardware,
      template_command: "mix mob.node.local_lifecycle.hardware_review --template --out <path>",
      review_command:
        "mix mob.node.local_lifecycle.hardware_review --input <path> --json --out <path>"
    },
    %{
      review_id: :multi_hop_hardware,
      template_command: "mix mob.node.local_multi_hop_hardware.review --template --out <path>",
      review_command:
        "mix mob.node.local_multi_hop_hardware.review --input <path> --json --out <path>"
    },
    %{
      review_id: :production_persistence,
      template_command:
        "mix mob.node.local_persistence.production_review --template --out <path>",
      review_command:
        "mix mob.node.local_persistence.production_review --input <path> --json --out <path>"
    },
    %{
      review_id: :release_candidate,
      template_command: "mix mob.node.local_release.candidate_review --template --out <path>",
      review_command:
        "mix mob.node.local_release.candidate_review --input <path> --json --out <path>"
    },
    %{
      review_id: :production_routing,
      template_command: "mix mob.node.local_routing.production_review --template --out <path>",
      review_command:
        "mix mob.node.local_routing.production_review --input <path> --json --out <path>"
    },
    %{
      review_id: :security_release,
      template_command: "mix mob.node.local_security.release_review --template --out <path>",
      review_command:
        "mix mob.node.local_security.release_review --input <path> --json --out <path>"
    }
  ]

  @spec snapshot() :: map()
  def snapshot do
    readiness = LocalProjectReadiness.snapshot()
    items = Enum.map(@objective_specs, &audit_item(&1, readiness))

    %{
      audit_version: 1,
      objective: :whole_project_completion,
      current_validated_mode: :advertisement_only_local_mesh,
      whole_project_complete?: false,
      completion_claim_allowed?: false,
      open_item_count: length(items),
      blocked_item_count: Enum.count(items, &(&1.status == :blocked)),
      partial_item_count: Enum.count(items, &(&1.status == :partial)),
      not_started_item_count: Enum.count(items, &(&1.status == :not_started)),
      items: items,
      checklist: checklist(),
      deliverables: deliverables(),
      prompt_artifact_checklist: prompt_artifact_checklist(items),
      blocker_matrix: LocalProjectCompletionBlockerMatrix.snapshot(),
      review_template_coverage: review_template_coverage(),
      required_commands: @required_commands,
      notes: [
        "Completion is false while any objective item remains blocked or partial.",
        "Advertisement-only local mesh is a coherent validated mode, not whole-project completion.",
        "Release wording must preserve the distinction between nearby observation and delivered/trusted/routed messages."
      ]
    }
  end

  @spec json_snapshot() :: map()
  def json_snapshot do
    snapshot()
    |> JSON.encode!()
    |> JSON.decode!()
  end

  defp deliverables do
    [
      "Resolve legacy beacon refs into full MessageEnvelope values through a real validated transport.",
      "Validate a known-good constrained fetch transport or explicitly choose and prove an alternate transport.",
      "Prove multi-hop advert gossip on physical participants, not only replay fixtures.",
      "Validate the Nearby Messages product surface on device.",
      "Decide whether local inbox persistence remains opt-in or becomes production-default, then validate that lifecycle.",
      "Add authenticated local identity, authorship, replay, and trust evidence before trusted-message wording.",
      "Implement production routing only if live delivery is required, with forwarding and delivery semantics.",
      "Validate mobile background lifecycle behavior only if product requirements need it.",
      "Implement and hardware-validate iOS advert-only participation if iOS participation is required.",
      "Package release-candidate evidence with hardware logs, manifests, and operator wording review."
    ]
  end

  defp review_template_coverage do
    entries =
      Enum.map(@review_template_commands, fn entry ->
        template_listed? = entry.template_command in @required_commands
        review_listed? = entry.review_command in @required_commands

        entry
        |> Map.put(:template_command_listed?, template_listed?)
        |> Map.put(:review_command_listed?, review_listed?)
        |> Map.put(:status, if(template_listed? and review_listed?, do: :covered, else: :open))
      end)

    %{
      boundary: :operator_review_template_coverage,
      all_review_templates_listed?: Enum.all?(entries, &(&1.status == :covered)),
      covered_review_count: Enum.count(entries, &(&1.status == :covered)),
      review_count: length(entries),
      entries: entries,
      notes: [
        "Every operator review command must have a matching --template command in the completion audit.",
        "Template coverage does not satisfy the underlying evidence gates or completion claim."
      ]
    }
  end

  defp prompt_artifact_checklist(items) do
    by_id = Map.new(items, &{&1.objective_id, &1})

    [
      prompt_check(
        1,
        :full_message_resolution,
        "Beacon refs still point to messages; contracts and fake/offline fetch work exist, but real fetch transport must retrieve and replay-parse a full MessageEnvelope before resolution is complete.",
        by_id,
        [
          "BeaconRef",
          "BeaconFetchRequest",
          "BeaconResolver",
          "LocalFetchTransportValidationPlan",
          "LocalFullMessageResolutionEvidenceManifest",
          "LocalFullMessageResolutionEvidenceReview",
          "LocalKnownGoodTransportEvidenceReview"
        ],
        [
          "mix test",
          "mix mob.node.local_full_resolution.evidence --json --out <path>",
          "mix mob.node.local_full_resolution.transport_review --template --out <path>",
          "mix mob.node.local_full_resolution.transport_review --input <path> --json --out <path>",
          "mix mob.node.local_known_good_transport.review --template --out <path>",
          "mix mob.node.local_known_good_transport.review --input <path> --json --out <path>",
          "mix mob.node.local_readiness.audit --allow-open --json"
        ]
      ),
      prompt_check(
        2,
        :known_good_transport_validation,
        "SM-T577U/SM-T390 GATT is blocked by status 133 before service discovery; a known-good hardware pair must pass standalone GATT or another constrained fetch transport must be chosen and validated.",
        by_id,
        [
          "M66 transport re-evaluation gate",
          "LocalHardwareValidationGates",
          "LocalFetchTransportValidationPlan",
          "LocalFullMessageResolutionEvidenceManifest",
          "LocalKnownGoodTransportEvidenceReview",
          "docs/ble_transport_re_evaluation.md"
        ],
        [
          "mix mob.node.local_full_resolution.evidence --json --out <path>",
          "mix mob.node.local_known_good_transport.review --template --out <path>",
          "mix mob.node.local_known_good_transport.review --input <path> --json --out <path>",
          "mix mob.node.local_readiness.audit --allow-open --json"
        ]
      ),
      prompt_check(
        3,
        :multi_hop_hardware_proof,
        "Replay proves protocol behavior and one-hop legacy beacon gossip has hardware scope, but physical multi-hop beacon gossip still needs origin, relay, and observer roles on three devices or an equivalent controlled rig.",
        by_id,
        [
          "Advert gossip scenario fixtures",
          "LocalHardwareValidationGates",
          "LocalAdvertGossipHardwareValidationPlan",
          "LocalMultiHopHardwareEvidenceManifest",
          "LocalMultiHopHardwareEvidenceReview",
          "LocalRoutingHardwareValidationPlan"
        ],
        [
          "mix mob.node.local_multi_hop_hardware.evidence --json --out <path>",
          "mix mob.node.local_multi_hop_hardware.review --template --out <path>",
          "mix mob.node.local_multi_hop_hardware.review --input <path> --json --out <path>",
          "mix mob.node.advert_gossip.audit apps/mob_node/test/fixtures/advert_gossip_scenarios"
        ]
      ),
      prompt_check(
        4,
        :product_ux,
        "Nearby Messages native surface controls, state copy, filters, sorting, rows, and detail evidence exist, but production UX still needs target-device evidence for full message, unresolved ref, gossiped ref, stale ref, copy anchors, and visual density.",
        by_id,
        [
          "LocalInboxProductSurface",
          "LocalInboxNativeSurface",
          "LocalInboxStateCopy",
          "LocalInboxUxAcceptance",
          "LocalInboxUxValidationPlan",
          "LocalInboxUxOperatorCapturePlan",
          "LocalInboxUxTargetDeviceScenarioPlan",
          "LocalInboxUxDecisionScenarioPlan",
          "LocalInboxUxEvidenceManifest",
          "LocalInboxUxEvidenceReview"
        ],
        [
          "mix test",
          "mix mob.node.local_inbox.ux_validation_plan --json --out <path>",
          "mix mob.node.local_inbox.ux_evidence --json --out <path>",
          "mix mob.node.local_inbox.ux_review --template --out <path>",
          "mix mob.node.local_inbox.ux_review --input <path> --json --out <path>"
        ]
      ),
      prompt_check(
        5,
        :persistence,
        "Local inbox remains memory-only by default; opt-in durable snapshots exist, but production-default message/ref persistence requires an explicit policy decision and lifecycle validation.",
        by_id,
        [
          "LocalInboxStore",
          "LocalInboxPersistenceLifecycle",
          "LocalPersistenceAcceptance",
          "LocalPersistenceProductionLifecyclePlan",
          "LocalPersistenceOperatorCapturePlan",
          "LocalPersistenceDefaultDecisionScenarioPlan",
          "LocalPersistenceEvidenceManifest",
          "LocalPersistenceProductionEvidenceReview"
        ],
        [
          "mix test",
          "mix mob.node.local_persistence.lifecycle_plan --json --out <path>",
          "mix mob.node.local_persistence.evidence --json --out <path>",
          "mix mob.node.local_persistence.production_review --template --out <path>",
          "mix mob.node.local_persistence.production_review --input <path> --json --out <path>"
        ]
      ),
      prompt_check(
        6,
        :security_identity,
        "Pure authorship, peer-binding, replay, and trust decision boundaries exist, but current BLE refs remain unsigned hash references until authenticated identity evidence, beacon authentication, and trust lifecycle evidence are integrated and reviewed.",
        by_id,
        [
          "LocalSecurityAcceptance",
          "LocalSecurityIdentityValidationPlan",
          "LocalSecurityAuthorshipProof",
          "LocalSecurityReplayProtection",
          "LocalSecurityCryptoNegativeValidation",
          "LocalSecurityDecisionScenarioPlan",
          "LocalSecurityOperatorCapturePlan",
          "LocalSecurityReleaseEvidenceReview",
          "LocalSecurityEvidenceManifest"
        ],
        [
          "mix test",
          "mix mob.node.local_security.validation_plan --json --out <path>",
          "mix mob.node.local_security.evidence --json --out <path>",
          "mix mob.node.local_security.release_review --template --out <path>",
          "mix mob.node.local_security.release_review --input <path> --json --out <path>"
        ]
      ),
      prompt_check(
        7,
        :routing,
        "Replay gossip, route candidates, and keep-advert-only non-routing policy exist, but production routing still needs validated route table, selection, forwarding, and delivery semantics.",
        by_id,
        [
          "LocalRoutingAcceptance",
          "LocalRoutingTable",
          "LocalRoutingHardwareValidationPlan",
          "LocalRoutingOperatorCapturePlan",
          "LocalRoutingDecisionScenarioPlan",
          "LocalRoutingNegativeValidation",
          "LocalRoutingEvidenceManifest",
          "LocalRoutingProductionEvidenceReview"
        ],
        [
          "mix test",
          "mix mob.node.local_routing.validation_plan --json --out <path>",
          "mix mob.node.local_routing.evidence --json --out <path>",
          "mix mob.node.local_routing.production_review --template --out <path>",
          "mix mob.node.local_routing.production_review --input <path> --json --out <path>"
        ]
      ),
      prompt_check(
        8,
        :background_mobile_lifecycle,
        "Foreground/manual lifecycle policy and evidence exist, but they are not background lifecycle proof for Android foreground service, iOS background behavior, restart, scheduled retry, or background gossip.",
        by_id,
        [
          "LocalLifecycleAcceptance",
          "LocalLifecycleHardwareValidationPlan",
          "LocalLifecycleOperatorCapturePlan",
          "LocalLifecycleDecisionScenarioPlan",
          "LocalLifecycleNegativeValidation",
          "LocalLifecycleEvidenceManifest",
          "LocalLifecycleHardwareEvidenceReview"
        ],
        [
          "mix test",
          "mix mob.node.local_lifecycle.validation_plan --json --out <path>",
          "mix mob.node.local_lifecycle.evidence --json --out <path>",
          "mix mob.node.local_lifecycle.hardware_review --template --out <path>",
          "mix mob.node.local_lifecycle.hardware_review --input <path> --json --out <path>"
        ]
      ),
      prompt_check(
        9,
        :ios_parity,
        "iOS contract and foreground observe source evidence exist, but Android legacy beacon gossip proof does not prove iOS advert-only participation, beacon gossip emission, full-envelope adverts, or iOS hardware parity.",
        by_id,
        [
          "LocalIOSParityAcceptance",
          "LocalIOSParityHardwareValidationPlan",
          "LocalIOSParityOperatorCapturePlan",
          "LocalIOSParityDecisionScenarioPlan",
          "LocalIOSParityNegativeValidation",
          "LocalIOSParityEvidenceManifest",
          "LocalIOSParityHardwareEvidenceReview"
        ],
        [
          "mix test",
          "mix mob.node.local_ios_parity.evidence --json --out <path>",
          "mix mob.node.local_ios_parity.hardware_review --template --out <path>",
          "mix mob.node.local_ios_parity.hardware_review --input <path> --json --out <path>"
        ]
      ),
      prompt_check(
        10,
        :release_hardening,
        "Release hardening requires fresh hardware attachments, generated manifests, and operator wording review for each release candidate.",
        by_id,
        [
          "LocalReleaseArtifactBundle",
          "LocalReleaseOperatorCapturePlan",
          "LocalReleaseCandidateEvidenceReview",
          "LocalReleaseRecentEvidenceInventory",
          "mix mob.node.local_release.candidate_review --template --out <path>",
          "mix mob.node.local_release.candidate_review --input <path> --json --out <path>",
          "LocalReleaseManifest",
          "docs/local_ble_release_artifact_bundle.md"
        ],
        [
          "mix mob.node.local_release.artifact_bundle --json --out <path>",
          "mix mob.node.local_release.candidate_review --template --out <path>",
          "mix mob.node.local_release.candidate_review --input <path> --json --out <path>",
          "mix mob.node.local_release.manifest --json --out <path>",
          "mix mob.node.local_release.recent_evidence --json --out <path>",
          "git diff --check"
        ]
      )
    ]
  end

  defp prompt_check(number, objective_id, prompt_requirement, by_id, artifacts, commands) do
    item = Map.fetch!(by_id, objective_id)

    %{
      number: number,
      objective_id: objective_id,
      prompt_requirement: prompt_requirement,
      status: item.status,
      completion_claim_allowed?: false,
      current_evidence: item.current_evidence,
      required_artifacts: artifacts ++ item.required_artifacts,
      missing_evidence: item.missing_evidence,
      verification_commands: commands,
      notes: item.notes
    }
  end

  defp audit_item(spec, readiness) do
    readiness_item = item_for!(readiness, spec.readiness_id)

    %{
      objective_id: spec.objective_id,
      title: spec.title,
      readiness_id: spec.readiness_id,
      status: readiness_item.status,
      completion_claim_allowed?: false,
      current_evidence: readiness_item.current_evidence,
      required_artifacts: spec.required_artifacts,
      missing_evidence: spec.missing_evidence ++ readiness_item.remaining_work,
      notes: spec.notes ++ readiness_item.notes
    }
  end

  defp item_for!(readiness, id) do
    Enum.find(readiness.open_items, &(&1.id == id)) ||
      raise ArgumentError, "missing readiness item #{inspect(id)}"
  end

  defp checklist do
    [
      %{
        id: :completion_gate,
        status: :blocked,
        evidence: ["LocalProjectReadiness", "LocalProjectCompletionAudit"],
        missing: [
          "All blocked and partial objective items must close before completion is claimable."
        ]
      },
      %{
        id: :release_gate,
        status: :limited,
        evidence: ["LocalReleaseCriteria", "LocalReleaseManifest"],
        missing: [
          "Release-candidate artifact bundle with concrete hardware evidence and operator notes."
        ]
      },
      %{
        id: :replay_gate,
        status: :satisfied,
        evidence: [
          "Canonical replay ingress",
          "Advert gossip scenario audit",
          "Replay-normalized hardware evidence requirements"
        ],
        missing: []
      },
      %{
        id: :hardware_gate,
        status: :blocked,
        evidence: ["LocalReleaseEvidenceManifest", "LocalHardwareValidationGates"],
        missing: [
          "Known-good full-message resolution transport proof.",
          "Physical multi-hop proof.",
          "iOS advert-only hardware proof."
        ]
      }
    ]
  end
end
