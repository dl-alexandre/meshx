defmodule Mob.Node.BLE.LocalProjectReadiness do
  @moduledoc """
  Current completion audit for the local BLE mesh project.

  This module records remaining project-level work as data. It does not
  inspect hardware, run validators, fetch messages, route, persist, ACK,
  retry, encrypt, or run in the background.
  """

  defmodule Item do
    @moduledoc false

    @enforce_keys [:id, :status, :current_evidence, :remaining_work, :notes]
    defstruct @enforce_keys

    @type id ::
            :full_message_resolution
            | :known_good_transport_validation
            | :multi_hop_hardware_proof
            | :product_ux
            | :persistence
            | :security_identity
            | :routing
            | :background_mobile_lifecycle
            | :ios_parity
            | :release_hardening

    @type status ::
            :blocked
            | :partial
            | :not_started

    @type t :: %__MODULE__{
            id: id(),
            status: status(),
            current_evidence: [binary()],
            remaining_work: [binary()],
            notes: [binary()]
          }
  end

  @item_specs [
    %{
      id: :full_message_resolution,
      status: :blocked,
      current_evidence: [
        "BeaconRef contract, BeaconFetchRequest contract, fake fetch transport, and fetch-intent projection exist.",
        "LocalFetchTransportValidationPlan ties real fetch transport evidence to canonical replay resolution while keeping beacon refs unresolved.",
        "LocalFullMessageResolutionEvidenceManifest packages current resolver/fetch contract evidence and blocked real transport gates.",
        "LocalFullMessageResolutionEvidenceReview validates operator-supplied real transport metadata without enabling resolution claims.",
        "LocalKnownGoodTransportEvidenceReview validates the known-good transport prerequisite without enabling fetch claims."
      ],
      remaining_work: [
        "Satisfy LocalFetchTransportValidationPlan candidate transport, standalone interop, constrained fetch, canonical replay, negative failure, and release artifact gates, then run LocalFullMessageResolutionEvidenceReview against the supplied metadata.",
        "Validate a real transport that retrieves and parses one full MessageEnvelope from a beacon ref.",
        "Keep unresolved beacon refs as pointers until that transport proof passes."
      ],
      notes: ["GATT fetch is blocked on the current SM-T577U/SM-T390 hardware pair."]
    },
    %{
      id: :known_good_transport_validation,
      status: :blocked,
      current_evidence: [
        "M66 gate, standalone GATT harness, hardware validation gates, LocalFetchTransportValidationPlan, and LocalFullMessageResolutionEvidenceManifest record the current blocker.",
        "Fresh May 13, 2026 standalone GATT interop logs for SM-T577U/SM-T390 are archived under artifacts/local-ble/2026-05-13-sm-t577u-sm-t390/hardware/m40-gatt-interop-rerun/ and still show status 133 before service discovery in both directions.",
        "LocalKnownGoodTransportEvidenceReview validates operator-supplied transport decision and standalone interop metadata without enabling fetch claims."
      ],
      remaining_work: [
        "Satisfy LocalFetchTransportValidationPlan candidate transport and standalone interop gates before enabling any real fetch path, then run LocalKnownGoodTransportEvidenceReview against the supplied metadata.",
        "Find a hardware pair that passes standalone GATT connect, discovery, and tiny read/write.",
        "Or choose and validate a different constrained fetch transport."
      ],
      notes: ["No real full-envelope retrieval transport is validated yet."]
    },
    %{
      id: :multi_hop_hardware_proof,
      status: :blocked,
      current_evidence: [
        "Replay topology fixtures and audit gate prove deterministic multi-hop policy.",
        "SM-T577U to SM-T390 proves one-hop legacy beacon gossip.",
        "LocalAdvertGossipHardwareValidationPlan records origin, relay, observer, replay-normalization, TTL/suppression, negative, and release evidence gates.",
        "LocalMultiHopHardwareEvidenceManifest packages replay evidence, current one-hop hardware scope, and blocked physical multi-hop gates.",
        "LocalMultiHopHardwareEvidenceReview validates operator-supplied physical multi-hop metadata without enabling multi-hop claims."
      ],
      remaining_work: [
        "Satisfy LocalAdvertGossipHardwareValidationPlan three-role device matrix, origin/relay/observer capture, replay fixture, TTL/suppression, one-hop negative, and release artifact gates, then run LocalMultiHopHardwareEvidenceReview against the supplied metadata.",
        "Run three or more physical participants, or an equivalent controlled physical rig.",
        "Capture origin, relay, and observer logs proving hop propagation without fake delivery."
      ],
      notes: ["Replay proof and hardware proof remain separate gates."]
    },
    %{
      id: :product_ux,
      status: :partial,
      current_evidence: [
        "LocalInboxView, LocalInboxQuery, LocalInboxProductSurface, LocalInboxNativeSurface, LocalInboxStateCopy, LocalInboxUxAcceptance, LocalInboxUxValidationPlan, LocalInboxUxOperatorCapturePlan, LocalInboxUxTargetDeviceScenarioPlan, LocalInboxUxDecisionScenarioPlan, LocalInboxUxEvidenceManifest, LocalInboxUxEvidenceReview, LocalInboxResolution, trust classification, action summary, local inbox presenter, nearby-message read models, Mob Nearby Messages controls, summary line, state-specific empty copy, control summaries, selected detail evidence, UX coverage summary, and per-state blocked-claim copy exist."
      ],
      remaining_work: [
        "Attach evidence satisfying LocalInboxUxValidationPlan target device, state coverage, interaction, selected detail limitation_copy, next_action_copy, blocked_claim_copy, and visual density gates and run LocalInboxUxEvidenceReview against it.",
        "Validate the Mob Nearby Messages controls on device and refine visual density if this becomes a production user-facing surface."
      ],
      notes: [
        "The native app surface model now drives Mob state filters, sorting choices, control summaries, row selection, detail text, selected detail evidence, coverage-summary review output, per-state blocked-claim copy, centralized state copy, and pure UX acceptance gates without adding transport behavior."
      ]
    },
    %{
      id: :persistence,
      status: :partial,
      current_evidence: [
        "Persistence policy, persistence profile, current default decision_outcome keep_memory_only_default, durable snapshot contract, CubDB store boundary, durable restore, explicit store listing/pruning, explicit operator persistence controls, LocalPersistenceAcceptance, LocalPersistenceProductionLifecyclePlan, LocalPersistenceOperatorCapturePlan, LocalPersistenceDefaultDecisionScenarioPlan, LocalPersistenceEvidenceManifest, LocalPersistenceProductionEvidenceReview, opt-in Session save/restore lifecycle hooks, and persistence negative validation exist."
      ],
      remaining_work: [
        "Satisfy the LocalPersistenceAcceptance production_default_lifecycle gate if product requirements need default persistence.",
        "Attach operator/release evidence for the selected decision_outcome before changing persistence claims.",
        "Promote durable Session persistence to the default app lifecycle only if decision_outcome selects it and production persistence gates pass.",
        "Satisfy LocalPersistenceProductionLifecyclePlan gates for product decision_outcome, migrations, scheduled cleanup execution, background-safe write integration, on-device restore fixtures, and release artifact evidence if product requirements need default persistence, then run LocalPersistenceProductionEvidenceReview against the supplied metadata."
      ],
      notes: [
        "The lifecycle decision keeps default app sessions memory-only while allowing opt-in durable snapshots; negative validation blocks delivery, background, and default-lifecycle overclaims."
      ]
    },
    %{
      id: :security_identity,
      status: :partial,
      current_evidence: [
        "Trust classification explicitly marks current observations as unsigned or locally validated only.",
        "LocalTrustPolicy records decision_outcome keep_unsigned_local_observation for the current validated advert-only mode.",
        "LocalTrustPolicy blocks trusted-message and delivery wording for current local BLE observations.",
        "LocalSecurityTrustModel defines future trust states and required proof gates without trusting current observations.",
        "LocalSecurityAcceptance ties current trust policy, future proof gates, and blocked authenticated/trusted claims into one acceptance boundary.",
        "LocalSecurityIdentityContract records the required future proof categories for authenticated local BLE messages.",
        "LocalSecurityIdentityProofPlan maps every open proof category to implementation gates and validation evidence.",
        "LocalSecurityPeerEnrollment records explicit operator-supplied peer/key enrollment while rejecting passive BLE observations as enrollment evidence.",
        "LocalSecurityAuthorshipProof provides a pure Ed25519 authorship verifier boundary for full MessageEnvelope values when supplied key material is available.",
        "LocalSecurityPeerIdentityBinding binds a peer_id to supplied Ed25519 public key material and validates authorship proofs against that binding.",
        "LocalSecurityReplayProtection provides a bounded in-memory replay guard for verified full-envelope proofs.",
        "LocalSecurityReplayLifecyclePolicy records replay state as memory-only and cleared on process restart.",
        "LocalSecurityReplayLifecycleValidation proves duplicate rejection, pruning, restart clearing, expiry, and beacon-ref rejection for the memory-only replay guard.",
        "LocalSecurityTrustedMessageDecision combines peer binding, authorship, replay protection, and explicit peer trust state for full-envelope trusted-message decisions.",
        "LocalSecurityCanonicalReplayDecision evaluates replay-normalized ReceivedMessage events with supplied proof, binding, replay state, and explicit peer trust state.",
        "LocalSecurityOperatorTrustPolicy scopes explicit operator trust to a supplied peer_id and Ed25519 key_id binding.",
        "LocalSecurityTrustLifecyclePlan records persistent key/trust lifecycle gates for enrollment, storage, rotation, revocation, replay state, and release audit export.",
        "LocalSecurityTrustLifecycleValidation proves supplied-policy key rotation and revocation cases fail closed without persistence or delivery claims.",
        "LocalSecurityIdentityValidationPlan records peer enrollment, authorship, replay lifecycle, trust lifecycle, canonical replay, beacon authentication, release evidence, and negative claim review gates.",
        "LocalSecurityFixtureAudit inventories implementation-backed security fixture coverage against every LocalSecurityIdentityValidationPlan gate.",
        "LocalSecurityDecisionScenarioPlan records keep_unsigned_local_observation and enable_authenticated_local_trust scenarios without enabling trusted claims.",
        "LocalSecurityOperatorCapturePlan maps security release gates to operator artifact slots without enabling authenticated or trusted claims.",
        "LocalSecurityReleaseEvidenceReview defines the operator-reviewed security evidence package required before authenticated/trusted wording can be considered.",
        "LocalSecurityEvidenceManifest packages current security gates, fixture evidence, blocked claims, and release review state as an archiveable artifact.",
        "LocalSecurityBeaconAuthentication authenticates legacy beacon refs only after they match a resolved trusted full envelope.",
        "LocalSecurityCryptoNegativeValidation runs executable negative cases for tamper, replay, key mismatch, blocked/revoked policy, and hash-only beacon promotion.",
        "LocalSecurityIdentityNegativeValidation records current cases that must not be promoted to trusted/authenticated/delivered claims."
      ],
      remaining_work: [
        "Attach operator/release evidence for the selected security decision_outcome before changing trusted-message claims.",
        "Satisfy the LocalSecurityAcceptance authenticated identity, authorship, replay protection, and beacon authentication gates with implementation-backed evidence.",
        "Satisfy LocalSecurityIdentityValidationPlan gates with implementation-backed peer enrollment, authorship, replay lifecycle, trust lifecycle, canonical replay, beacon authentication, release evidence, and negative fixtures.",
        "Integrate LocalSecurityBeaconAuthentication with canonical replay fixtures once full-envelope resolution transport evidence exists.",
        "Integrate the authorship verifier with peer identity binding, trust policy, and canonical replay fixtures.",
        "Integrate replay protection with trust policy, persistent lifecycle decisions if required, and canonical replay fixtures.",
        "Implement LocalSecurityTrustLifecyclePlan gates if product requirements need persistent trusted-message wording.",
        "Implement durable crypto-backed trust policy transitions.",
        "Expand crypto-backed positive and negative fixtures across persistent trust lifecycle, key rotation, trust revocation, and hash-only beacon promotion."
      ],
      notes: [
        "Current hashes are references, not proof of authorship; trust policy and trust model remain gates, not crypto."
      ]
    },
    %{
      id: :routing,
      status: :partial,
      current_evidence: [
        "Advert gossip replay simulation and suppression policy exist.",
        "LocalRoutingTable derives deterministic direct-route candidates from peer observations without enabling routing claims.",
        "LocalRoutingPolicy records decision_outcome keep_advert_only_non_routing and blocks live routing, forwarding, and delivery claims for the current advert-only mode.",
        "LocalRoutingAcceptance ties observation policy, route candidates, future routing contracts, and blocked forwarding/delivery claims into one acceptance boundary.",
        "LocalRoutingContract records the missing production routing requirements.",
        "LocalRoutingProofPlan maps routing requirements to implementation gates and validation evidence.",
        "LocalRoutingHardwareValidationPlan records route table, route selection, forwarding, delivery, multi-hop rig, TTL/loop, release evidence, and negative claim review gates.",
        "LocalRoutingOperatorCapturePlan maps production routing gates to operator artifact slots without enabling routing.",
        "LocalRoutingNegativeValidation records current cases that must not be promoted to route selection, forwarding, delivery, or multi-hop hardware claims.",
        "LocalRoutingDecisionScenarioPlan records keep_advert_only_non_routing and enable_production_routing scenarios without enabling routing claims.",
        "LocalRoutingEvidenceManifest packages current route-candidate evidence, non-routing policy, open hardware gates, and blocked routing claims.",
        "LocalRoutingProductionEvidenceReview validates operator-supplied production routing evidence metadata without enabling routing claims."
      ],
      remaining_work: [
        "Attach operator/release evidence for the selected routing decision_outcome before changing routing claims.",
        "Satisfy the LocalRoutingAcceptance production routing table, route selection, forwarding service, delivery semantics, and multi-hop hardware gates if MeshX needs live routing.",
        "Satisfy LocalRoutingHardwareValidationPlan gates with route table, route selection, forwarding, delivery, multi-hop hardware, TTL/loop, release, and negative evidence if MeshX needs live routing, then run LocalRoutingProductionEvidenceReview against the supplied metadata.",
        "Promote route candidates to a production routing table and route selection policy only if MeshX needs live routing.",
        "Implement forwarding service, ACK/retry policy, and delivery semantics if product requirements need them.",
        "Validate loop/TTL behavior on multi-device hardware.",
        "Replace the current negative validation matrix with implementation-backed negative fixtures for stale routes, unreachable next hops, missing ACK/retry policy, and delivery failure surfaces."
      ],
      notes: [
        "The current validated mode is local advertisement observation, not live routing."
      ]
    },
    %{
      id: :background_mobile_lifecycle,
      status: :partial,
      current_evidence: [
        "Foreground/manual lifecycle profile records supported and unsupported behavior.",
        "LocalLifecyclePolicy records decision_outcome keep_foreground_manual and blocks background, restart, scheduled retry, and background gossip claims.",
        "LocalLifecycleAcceptance ties foreground/manual profile, lifecycle policy, future lifecycle contracts, and blocked background/restart claims into one acceptance boundary.",
        "LocalBackgroundLifecycleContract records the missing background lifecycle requirements.",
        "LocalLifecycleProofPlan maps background lifecycle requirements to implementation gates and validation evidence.",
        "LocalLifecycleHardwareValidationPlan records device matrix, app-backgrounding, restart, scheduled retry, background gossip, and negative claim review evidence gates.",
        "LocalLifecycleOperatorCapturePlan maps lifecycle hardware gates to operator artifact slots without enabling background behavior.",
        "LocalLifecycleNegativeValidation records current cases that must not be promoted to background service, restart, scheduled retry, or background gossip claims.",
        "LocalLifecycleDecisionScenarioPlan records keep_foreground_manual and enable_background_lifecycle scenarios without enabling background claims.",
        "LocalLifecycleEvidenceManifest packages foreground/manual lifecycle evidence, open hardware gates, and blocked background lifecycle claims.",
        "LocalLifecycleHardwareEvidenceReview validates operator-supplied lifecycle hardware metadata without enabling background claims."
      ],
      remaining_work: [
        "Attach operator/release evidence for the selected lifecycle decision_outcome before changing background lifecycle claims.",
        "Satisfy the LocalLifecycleAcceptance Android foreground service, Android/iOS background BLE, automatic restart, scheduled retry, and background gossip gates if product requirements need them.",
        "Satisfy LocalLifecycleHardwareValidationPlan gates with device-specific lifecycle logs and implementation-backed negative fixtures if background behavior is required, then run LocalLifecycleHardwareEvidenceReview against the supplied metadata.",
        "Implement and validate Android foreground service behavior if required.",
        "Implement and validate iOS background behavior if required.",
        "Implement automatic restart, scheduled retry, or background gossip only if product requirements need them.",
        "Replace the current negative validation matrix with implementation-backed negative fixtures for app-backgrounding logs, OS throttling, restart cancellation, and background gossip bounds before any background claims."
      ],
      notes: [
        "Current BLE validation is foreground/manual harness style; lifecycle policy is claim gating, not a background implementation."
      ]
    },
    %{
      id: :ios_parity,
      status: :partial,
      current_evidence: [
        "iOS bridge shell and shared canonical ingress contract exist.",
        "iOS foreground scanner decode path now maps MeshX legacy beacon manufacturer advertisements into canonical received_message_beacon wire maps.",
        "LocalIOSAdvertCarrierDecision records foreground legacy-beacon observe as hardware_validated and foreground iOS MB beacon emit as implemented_unvalidated, while keeping iOS beacon gossip and direct full-MX extended advertising blocked.",
        "LocalHardwareValidationGates records iOS advert-only participation as partial, with Android fetch from iOS MobFetchGattResponder hardware evidence archived under artifacts/local-ble/2026-05-17-sm-t577u-ipad9/.",
        "LocalIOSParityPolicy preserves partial iOS hardware evidence while blocking broad parity, gossip, direct full-MX extended advertising, and background claims.",
        "LocalIOSParityAcceptance ties shared canonical contracts, iOS proof gates, and blocked iOS participation claims into one acceptance boundary.",
        "LocalIOSParityContract records the missing iOS advert-only implementation and validation requirements.",
        "LocalIOSParityProofPlan maps iOS parity requirements to implementation gates and replay-normalized hardware evidence.",
        "LocalIOSParityHardwareValidationPlan records iOS device matrix, beacon observe/gossip, full-envelope capability, replay fixture, background boundary, and negative claim review evidence gates; it treats the SM-T577U -> iPad12,1 AUX scan-response probe and 11:19 rerun as blocked negative capability evidence.",
        "LocalIOSParityNegativeValidation records current cases that must not be promoted to iOS hardware participation or parity claims.",
        "LocalIOSParityOperatorCapturePlan maps iOS parity hardware gates to operator artifact slots without enabling iOS participation claims.",
        "LocalIOSParityDecisionScenarioPlan records keep_ios_contract_only and enable_ios_advert_only_participation scenarios without enabling iOS parity claims.",
        "LocalIOSParityEvidenceManifest packages partial iOS hardware evidence, including the negative android-aux-full-mx-ios-observe probe and android-aux-full-mx-ios-observe-rerun, open hardware gates, and blocked parity claims.",
        "LocalIOSParityHardwareEvidenceReview validates operator-supplied iOS hardware metadata without enabling iOS participation claims."
      ],
      remaining_work: [
        "Satisfy the LocalIOSParityAcceptance legacy beacon gossip, full-envelope advert, hardware replay fixture, and iOS background BLE gates if broader iOS participation is required.",
        "Satisfy LocalIOSParityHardwareValidationPlan gates with iOS-specific device logs, replay fixtures, and implementation-backed negative fixtures if iOS participation is required, then run LocalIOSParityHardwareEvidenceReview against the supplied metadata.",
        "Capture Android receipt of iOS-origin MB beacons, replay-normalize the evidence, and bound it with negative fixtures before any iOS legacy beacon gossip claim.",
        "Keep direct full-MX extended advertising disabled on iOS unless a future hardware/API path proves AUX manufacturer-data delivery.",
        "Capture iOS hardware evidence that normalizes through the same replay path.",
        "Add iOS advert-only replay fixtures or validation ledgers.",
        "Replace the current negative validation matrix with implementation-backed iOS fixtures for device model/version, legacy beacon observe/gossip, full-envelope capability, and canonical replay before any iOS parity claim."
      ],
      notes: [
        "Android has the validated legacy beacon gossip path; iOS has validated foreground legacy-beacon observe, foreground MB beacon emit code, and Android fetch from iOS responder, but no iOS-origin cross-radio gossip proof and both direct full-MX AUX probes remain negative."
      ]
    },
    %{
      id: :release_hardening,
      status: :partial,
      current_evidence: [
        "Advert gossip scenario audit gate, local readiness audit task with JSON output/artifact support, capability profiles, platform parity, hardware validation gates, hardware evidence manifest, advert-only release criteria, local release manifest output, whole-project completion audit, focused remaining-items audit, recent-evidence inventory, and release artifact bundle checklist exist.",
        "Local release artifact bundle task emits the operator checklist, direct full-MX AUX validation checklist, upstream patch maintainer handoff, focused remaining-items audit, and recent-evidence inventory as archiveable artifacts.",
        "Local release candidate review task validates supplied hardware attachment metadata, operator wording, required blocked claims, and closure artifact paths as archiveable JSON.",
        "LocalReleaseOperatorCapturePlan maps release-candidate manifest, review, hardware, note, and final review inputs to operator artifact slots without enabling release completion claims.",
        "LocalReleaseCandidateEvidenceReview defines the operator-supplied hardware attachment and release-note review contract for each advert-only release candidate while requiring direct_full_mx_aux_complete and upstream_patch_migration_complete to remain blocked claims.",
        "LocalFocusedRemainingItemsAudit and LocalReleaseRecentEvidenceInventory keep direct full-MX AUX interop and upstream patch migration incomplete while archiving closure pointers.",
        "Current Android advert-only hardware logs, readiness/release manifests, advert gossip audit output, and operator wording notes are archived under artifacts/local-ble/2026-05-12-sm-t577u-sm-t390/.",
        "Fresh May 13, 2026 standalone GATT blocker logs are archived under artifacts/local-ble/2026-05-13-sm-t577u-sm-t390/hardware/m40-gatt-interop-rerun/.",
        "docs/upstream_mob_patches.md records GenericJam/mob_dev#6 and GenericJam/mob_new#5 as open upstream replacement PRs; the downstream patch path remains verified by mix mob.patch_deps --check.",
        "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/upstream-pr-recheck-1358/ archives raw gh JSON showing both upstream PRs still open and this token still READ-only."
      ],
      remaining_work: [
        "Attach fresh concrete hardware logs and operator-authored release notes to the artifact bundle for each future release candidate.",
        "Run the release-candidate evidence through LocalReleaseCandidateEvidenceReview or the local release candidate review task before any operator release note is accepted.",
        "Close the direct full-MX AUX validation checklist only after iOS callback proof, canonical FF FF 4D 58 parse proof, MB fallback control, and negative-boundary notes are archived.",
        "Keep patches/, mix mob.patch_deps, and the locked downstream patch path until GenericJam/mob_dev#6 and GenericJam/mob_new#5 are merged, released, MeshX migrates to those dependency versions, and the post-merge verification gates pass."
      ],
      notes: [
        "Release criteria, CI manifest generation, the archived hardware evidence, focused audit, recent-evidence inventory, AUX checklist, and upstream patch handoff define the constrained local mode; release hardening remains partial because each release candidate still needs fresh operator-reviewed attachments, direct full-MX AUX completion is blocked, and upstream patch migration is not complete."
      ]
    }
  ]

  @spec items() :: [Item.t()]
  def items, do: Enum.map(@item_specs, &struct!(Item, &1))

  @spec get(Item.id()) :: {:ok, Item.t()} | {:error, :not_found}
  def get(id) do
    case Enum.find(items(), &(&1.id == id)) do
      %Item{} = item -> {:ok, item}
      nil -> {:error, :not_found}
    end
  end

  @spec open_items() :: [Item.t()]
  def open_items, do: items()

  @spec snapshot() :: map()
  def snapshot do
    %{
      items: items(),
      open_items: open_items(),
      open_item_count: length(open_items()),
      blocked_item_count: Enum.count(items(), &(&1.status == :blocked)),
      partial_item_count: Enum.count(items(), &(&1.status == :partial)),
      not_started_item_count: Enum.count(items(), &(&1.status == :not_started)),
      notes: [
        "Advertisement-only local mesh is the current validated mode.",
        "Full message resolution from beacon refs remains blocked on real transport validation.",
        "Durable local inbox storage exists, but automatic lifecycle persistence is still open."
      ]
    }
  end
end
