defmodule Mob.Node.BLE.LocalProjectReadinessTest do
  use ExUnit.Case, async: true

  alias Mob.Node.BLE.{LocalInbox, LocalProjectReadiness}

  test "full message resolution remains blocked on real transport validation" do
    assert {:ok, item} = LocalProjectReadiness.get(:full_message_resolution)

    assert item.status == :blocked
    assert Enum.any?(item.current_evidence, &String.contains?(&1, "fake fetch transport"))

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "LocalFetchTransportValidationPlan")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "LocalFullMessageResolutionEvidenceManifest")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "LocalKnownGoodTransportEvidenceReview")
           )

    assert Enum.any?(
             item.remaining_work,
             &String.contains?(&1, "LocalFetchTransportValidationPlan")
           )

    assert Enum.any?(item.remaining_work, &String.contains?(&1, "real transport"))
    assert Enum.any?(item.notes, &String.contains?(&1, "GATT fetch is blocked"))
  end

  test "known-good transport validation references the fetch transport plan" do
    assert {:ok, item} = LocalProjectReadiness.get(:known_good_transport_validation)

    assert item.status == :blocked

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "LocalFetchTransportValidationPlan")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "LocalFullMessageResolutionEvidenceManifest")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "2026-05-13-sm-t577u-sm-t390")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "status 133 before service discovery")
           )

    assert Enum.any?(item.remaining_work, &String.contains?(&1, "candidate transport"))
    assert Enum.any?(item.remaining_work, &String.contains?(&1, "standalone interop"))

    assert Enum.any?(
             item.remaining_work,
             &String.contains?(&1, "LocalKnownGoodTransportEvidenceReview")
           )
  end

  test "multi-hop hardware proof references the advert gossip hardware plan" do
    assert {:ok, item} = LocalProjectReadiness.get(:multi_hop_hardware_proof)

    assert item.status == :blocked

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "LocalAdvertGossipHardwareValidationPlan")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "LocalMultiHopHardwareEvidenceManifest")
           )

    assert Enum.any?(
             item.remaining_work,
             &String.contains?(&1, "LocalAdvertGossipHardwareValidationPlan")
           )

    assert Enum.any?(item.remaining_work, &String.contains?(&1, "origin/relay/observer"))
  end

  test "persistence is partial rather than incorrectly marked absent" do
    assert {:ok, item} = LocalProjectReadiness.get(:persistence)

    assert item.status == :partial

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "decision_outcome keep_memory_only_default")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "operator persistence controls")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "LocalPersistenceAcceptance")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "LocalPersistenceProductionLifecyclePlan")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "LocalPersistenceOperatorCapturePlan")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "LocalPersistenceDefaultDecisionScenarioPlan")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "persistence negative validation")
           )

    assert Enum.any?(
             item.remaining_work,
             &String.contains?(&1, "LocalPersistenceAcceptance production_default_lifecycle")
           )

    assert Enum.any?(
             item.remaining_work,
             &String.contains?(&1, "operator/release evidence")
           )

    assert Enum.any?(
             item.remaining_work,
             &String.contains?(&1, "Promote durable Session persistence")
           )

    assert Enum.any?(
             item.remaining_work,
             &String.contains?(&1, "LocalPersistenceProductionLifecyclePlan")
           )
  end

  test "product UX records Mob controls while keeping device validation open" do
    assert {:ok, item} = LocalProjectReadiness.get(:product_ux)

    assert item.status == :partial

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "Mob Nearby Messages controls")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "LocalInboxStateCopy")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "summary line")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "control summaries")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "LocalInboxUxOperatorCapturePlan")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "LocalInboxUxTargetDeviceScenarioPlan")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "LocalInboxUxDecisionScenarioPlan")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "selected detail evidence")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "UX coverage summary")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "blocked-claim copy")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "LocalInboxUxAcceptance")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "LocalInboxUxValidationPlan")
           )

    assert Enum.any?(
             item.remaining_work,
             &String.contains?(&1, "LocalInboxUxValidationPlan")
           )

    assert Enum.any?(
             item.remaining_work,
             &String.contains?(&1, "limitation_copy")
           )

    assert Enum.any?(
             item.remaining_work,
             &String.contains?(&1, "next_action_copy")
           )

    assert Enum.any?(
             item.remaining_work,
             &String.contains?(&1, "blocked_claim_copy")
           )

    assert Enum.any?(
             item.remaining_work,
             &String.contains?(&1, "Validate the Mob Nearby Messages controls on device")
           )
  end

  test "snapshot covers the whole current project readiness checklist" do
    snapshot = LocalProjectReadiness.snapshot()
    ids = Enum.map(snapshot.items, & &1.id)

    assert snapshot.open_item_count == 10
    assert snapshot.blocked_item_count == 3
    assert snapshot.partial_item_count == 7
    assert snapshot.not_started_item_count == 0

    assert :known_good_transport_validation in ids
    assert :multi_hop_hardware_proof in ids
    assert :product_ux in ids
    assert :security_identity in ids
    assert :routing in ids
    assert :background_mobile_lifecycle in ids
    assert :ios_parity in ids
    assert :release_hardening in ids
  end

  test "release hardening references current archived blocker evidence without closing claims" do
    assert {:ok, item} = LocalProjectReadiness.get(:release_hardening)

    assert item.status == :partial

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "2026-05-12-sm-t577u-sm-t390")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "2026-05-13-sm-t577u-sm-t390")
           )

    assert Enum.any?(
             item.remaining_work,
             &String.contains?(&1, "release-candidate evidence")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "focused remaining-items audit")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "recent-evidence inventory")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "direct_full_mx_aux_complete")
           )
  end

  test "local inbox snapshot exposes project readiness" do
    snapshot = LocalInbox.new() |> LocalInbox.snapshot()

    assert snapshot.project_readiness.open_item_count == 10

    assert Enum.any?(
             snapshot.project_readiness.open_items,
             &(&1.id == :security_identity and &1.status == :partial)
           )

    assert Enum.any?(
             snapshot.project_readiness.open_items,
             &(&1.id == :routing and &1.status == :partial)
           )

    assert Enum.any?(
             snapshot.project_readiness.open_items,
             &(&1.id == :background_mobile_lifecycle and &1.status == :partial)
           )

    assert Enum.any?(
             snapshot.project_readiness.open_items,
             &(&1.id == :ios_parity and &1.status == :partial)
           )

    assert Enum.any?(
             snapshot.project_readiness.open_items,
             &(&1.id == :full_message_resolution and &1.status == :blocked)
           )
  end

  test "background lifecycle evidence includes lifecycle manifest while remaining partial" do
    assert {:ok, item} = LocalProjectReadiness.get(:background_mobile_lifecycle)

    assert item.status == :partial

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "LocalLifecycleEvidenceManifest")
           )

    assert Enum.any?(
             item.remaining_work,
             &String.contains?(&1, "LocalLifecycleHardwareValidationPlan")
           )
  end

  test "security identity evidence includes negative validation while remaining partial" do
    assert {:ok, item} = LocalProjectReadiness.get(:security_identity)

    assert item.status == :partial

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "LocalSecurityIdentityNegativeValidation")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "decision_outcome keep_unsigned_local_observation")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "LocalSecurityTrustModel")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "LocalSecurityAcceptance")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "LocalSecurityAuthorshipProof")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "LocalSecurityPeerIdentityBinding")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "LocalSecurityReplayProtection")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "LocalSecurityReplayLifecyclePolicy")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "LocalSecurityReplayLifecycleValidation")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "LocalSecurityTrustedMessageDecision")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "LocalSecurityCanonicalReplayDecision")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "LocalSecurityOperatorTrustPolicy")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "LocalSecurityTrustLifecyclePlan")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "LocalSecurityTrustLifecycleValidation")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "LocalSecurityIdentityValidationPlan")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "LocalSecurityPeerEnrollment")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "LocalSecurityFixtureAudit")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "LocalSecurityReleaseEvidenceReview")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "LocalSecurityDecisionScenarioPlan")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "LocalSecurityOperatorCapturePlan")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "LocalSecurityCryptoNegativeValidation")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "LocalSecurityBeaconAuthentication")
           )

    assert Enum.any?(
             item.remaining_work,
             &String.contains?(&1, "LocalSecurityAcceptance authenticated identity")
           )

    assert Enum.any?(
             item.remaining_work,
             &String.contains?(&1, "selected security decision_outcome")
           )

    assert Enum.any?(
             item.remaining_work,
             &String.contains?(&1, "LocalSecurityIdentityValidationPlan")
           )

    assert Enum.any?(
             item.remaining_work,
             &String.contains?(&1, "LocalSecurityBeaconAuthentication")
           )

    assert Enum.any?(
             item.remaining_work,
             &String.contains?(&1, "LocalSecurityTrustLifecyclePlan")
           )

    assert Enum.any?(
             item.remaining_work,
             &String.contains?(&1, "persistent trust lifecycle")
           )
  end

  test "routing evidence includes negative validation while remaining partial" do
    assert {:ok, item} = LocalProjectReadiness.get(:routing)

    assert item.status == :partial

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "decision_outcome keep_advert_only_non_routing")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "LocalRoutingNegativeValidation")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "LocalRoutingTable")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "LocalRoutingAcceptance")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "LocalRoutingHardwareValidationPlan")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "LocalRoutingOperatorCapturePlan")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "LocalRoutingDecisionScenarioPlan")
           )

    assert Enum.any?(
             item.remaining_work,
             &String.contains?(&1, "operator/release evidence")
           )

    assert Enum.any?(
             item.remaining_work,
             &String.contains?(&1, "LocalRoutingAcceptance production routing table")
           )

    assert Enum.any?(
             item.remaining_work,
             &String.contains?(&1, "implementation-backed negative fixtures")
           )
  end

  test "lifecycle evidence includes negative validation while remaining partial" do
    assert {:ok, item} = LocalProjectReadiness.get(:background_mobile_lifecycle)

    assert item.status == :partial

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "decision_outcome keep_foreground_manual")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "LocalLifecycleNegativeValidation")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "LocalLifecycleAcceptance")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "LocalLifecycleHardwareValidationPlan")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "LocalLifecycleOperatorCapturePlan")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "LocalLifecycleDecisionScenarioPlan")
           )

    assert Enum.any?(
             item.remaining_work,
             &String.contains?(&1, "operator/release evidence")
           )

    assert Enum.any?(
             item.remaining_work,
             &String.contains?(&1, "LocalLifecycleAcceptance Android foreground service")
           )

    assert Enum.any?(
             item.remaining_work,
             &String.contains?(&1, "implementation-backed negative fixtures")
           )
  end

  test "iOS parity evidence includes negative validation while remaining partial" do
    assert {:ok, item} = LocalProjectReadiness.get(:ios_parity)

    assert item.status == :partial

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "LocalIOSParityNegativeValidation")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "foreground scanner decode")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "LocalIOSAdvertCarrierDecision")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "LocalIOSParityAcceptance")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "LocalIOSParityHardwareValidationPlan")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "AUX scan-response probe")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "LocalIOSParityOperatorCapturePlan")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "LocalIOSParityDecisionScenarioPlan")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "LocalIOSParityEvidenceManifest")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "android-aux-full-mx-ios-observe")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "android-aux-full-mx-ios-observe-rerun")
           )

    assert Enum.any?(
             item.remaining_work,
             &String.contains?(&1, "LocalIOSParityAcceptance legacy beacon gossip")
           )

    assert Enum.any?(
             item.remaining_work,
             &String.contains?(&1, "LocalIOSParityHardwareValidationPlan")
           )

    assert Enum.any?(
             item.remaining_work,
             &String.contains?(&1, "Android receipt of iOS-origin MB beacons")
           )

    assert Enum.any?(
             item.remaining_work,
             &String.contains?(&1, "implementation-backed iOS fixtures")
           )

    assert Enum.any?(
             item.notes,
             &String.contains?(&1, "both direct full-MX AUX probes remain negative")
           )
  end

  test "release hardening evidence includes artifact bundle while attachments remain open" do
    assert {:ok, item} = LocalProjectReadiness.get(:release_hardening)

    assert item.status == :partial

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "release artifact bundle checklist")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "artifact bundle task")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "direct full-MX AUX validation checklist")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "upstream patch maintainer handoff")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "candidate review task")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "LocalReleaseOperatorCapturePlan")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "LocalReleaseCandidateEvidenceReview")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "upstream_patch_migration_complete")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "LocalFocusedRemainingItemsAudit")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "LocalReleaseRecentEvidenceInventory")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "artifacts/local-ble/2026-05-12-sm-t577u-sm-t390")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "GenericJam/mob_dev#6")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "mix mob.patch_deps --check")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "upstream-pr-recheck-1358")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "raw gh JSON")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "READ-only")
           )

    assert Enum.any?(
             item.remaining_work,
             &String.contains?(&1, "candidate review task")
           )

    assert Enum.any?(
             item.remaining_work,
             &String.contains?(&1, "GenericJam/mob_new#5")
           )

    assert Enum.any?(
             item.remaining_work,
             &String.contains?(&1, "post-merge verification gates")
           )

    assert Enum.any?(
             item.remaining_work,
             &String.contains?(&1, "canonical FF FF 4D 58 parse proof")
           )

    assert Enum.any?(
             item.notes,
             &String.contains?(&1, "direct full-MX AUX completion is blocked")
           )

    assert Enum.any?(
             item.notes,
             &String.contains?(&1, "upstream patch migration is not complete")
           )
  end
end
