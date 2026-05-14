defmodule MeshxMobileApp.BLE.LocalReleaseCriteriaTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.{LocalInbox, LocalProjectReadiness, LocalReleaseCriteria}

  test "advert-only profile is a satisfied release boundary" do
    assert {:ok, criterion} = LocalReleaseCriteria.get(:advert_only_profile)

    assert criterion.status == :satisfied
    assert Enum.any?(criterion.evidence, &String.contains?(&1, "AdvertOnlyTransportProfile"))
    assert Enum.any?(criterion.limitations, &String.contains?(&1, "No GATT fetch"))
  end

  test "release audit artifacts are satisfied but do not close readiness blockers" do
    assert {:ok, criterion} = LocalReleaseCriteria.get(:release_audit_artifacts)

    assert criterion.status == :satisfied

    assert Enum.any?(
             criterion.evidence,
             &String.contains?(&1, "meshx.mobile.local_readiness.audit")
           )

    assert "LocalReleaseCandidateEvidenceReview" in criterion.evidence

    assert Enum.any?(
             criterion.limitations,
             &String.contains?(&1, "does not convert partial work into completion")
           )
  end

  test "full-envelope observation remains limited to capability-proven hardware" do
    assert {:ok, criterion} = LocalReleaseCriteria.get(:full_envelope_observation)

    assert criterion.status == :limited

    assert Enum.any?(
             criterion.limitations,
             &String.contains?(&1, "Android-to-Android full-envelope proof is incomplete")
           )
  end

  test "nearby messages surface includes Mob controls but remains UX-limited" do
    assert {:ok, criterion} = LocalReleaseCriteria.get(:nearby_messages_surface)

    assert criterion.status == :satisfied
    assert "MeshxMobileApp.HomeScreen" in criterion.evidence
    assert "LocalInboxStateCopy" in criterion.evidence
    assert "LocalInboxUxAcceptance" in criterion.evidence
    assert "LocalInboxUxValidationPlan" in criterion.evidence
    assert "LocalInboxNativeSurface summary_line / empty_label" in criterion.evidence

    assert Enum.any?(
             criterion.limitations,
             &String.contains?(&1, "production UX claims blocked")
           )

    assert Enum.any?(
             criterion.limitations,
             &String.contains?(&1, "on-device UX validation")
           )
  end

  test "durable snapshot boundary records explicit persistence lifecycle decision" do
    assert {:ok, criterion} = LocalReleaseCriteria.get(:durable_snapshot_boundary)

    assert criterion.status == :limited
    assert "LocalInboxPersistenceLifecycle" in criterion.evidence
    assert "LocalInboxPersistenceOperator" in criterion.evidence
    assert "LocalPersistenceAcceptance" in criterion.evidence
    assert "LocalPersistenceNegativeValidation" in criterion.evidence
    assert "LocalPersistenceProductionLifecyclePlan" in criterion.evidence

    assert Enum.any?(
             criterion.limitations,
             &String.contains?(&1, "default lifecycle persistence blocked")
           )

    assert Enum.any?(
             criterion.limitations,
             &String.contains?(&1, "explicit opt-in")
           )

    assert Enum.any?(
             criterion.limitations,
             &String.contains?(&1, "LocalPersistenceProductionLifecyclePlan")
           )
  end

  test "explicit non-goals include security negative validation evidence" do
    assert {:ok, criterion} = LocalReleaseCriteria.get(:explicit_non_goals)

    assert criterion.status == :satisfied
    assert "LocalFetchTransportValidationPlan" in criterion.evidence
    assert "LocalFullMessageResolutionEvidenceManifest" in criterion.evidence
    assert "LocalAdvertGossipHardwareValidationPlan" in criterion.evidence
    assert "LocalMultiHopHardwareEvidenceManifest" in criterion.evidence
    assert "LocalPersistenceAcceptance" in criterion.evidence
    assert "LocalSecurityAcceptance" in criterion.evidence
    assert "LocalSecurityPeerEnrollment" in criterion.evidence
    assert "LocalSecurityAuthorshipProof" in criterion.evidence
    assert "LocalSecurityPeerIdentityBinding" in criterion.evidence
    assert "LocalSecurityReplayProtection" in criterion.evidence
    assert "LocalSecurityReplayLifecyclePolicy" in criterion.evidence
    assert "LocalSecurityReplayLifecycleValidation" in criterion.evidence
    assert "LocalSecurityTrustedMessageDecision" in criterion.evidence
    assert "LocalSecurityCanonicalReplayDecision" in criterion.evidence
    assert "LocalSecurityOperatorTrustPolicy" in criterion.evidence
    assert "LocalSecurityTrustLifecyclePlan" in criterion.evidence
    assert "LocalSecurityTrustLifecycleValidation" in criterion.evidence
    assert "LocalSecurityIdentityValidationPlan" in criterion.evidence
    assert "LocalSecurityBeaconAuthentication" in criterion.evidence
    assert "LocalSecurityCryptoNegativeValidation" in criterion.evidence
    assert "LocalSecurityFixtureAudit" in criterion.evidence
    assert "LocalSecurityReleaseEvidenceReview" in criterion.evidence
    assert "LocalSecurityTrustModel" in criterion.evidence
    assert "LocalRoutingTable" in criterion.evidence
    assert "LocalRoutingAcceptance" in criterion.evidence
    assert "LocalSecurityIdentityNegativeValidation" in criterion.evidence
    assert "LocalPersistenceNegativeValidation" in criterion.evidence
  end

  test "explicit non-goals include routing negative validation evidence" do
    assert {:ok, criterion} = LocalReleaseCriteria.get(:explicit_non_goals)

    assert criterion.status == :satisfied
    assert "LocalRoutingHardwareValidationPlan" in criterion.evidence
    assert "LocalRoutingNegativeValidation" in criterion.evidence
  end

  test "explicit non-goals include lifecycle negative validation evidence" do
    assert {:ok, criterion} = LocalReleaseCriteria.get(:explicit_non_goals)

    assert criterion.status == :satisfied
    assert "LocalLifecycleAcceptance" in criterion.evidence
    assert "LocalLifecycleHardwareValidationPlan" in criterion.evidence
    assert "LocalLifecycleNegativeValidation" in criterion.evidence
    assert "LocalLifecycleEvidenceManifest" in criterion.evidence
  end

  test "explicit non-goals include iOS parity negative validation evidence" do
    assert {:ok, criterion} = LocalReleaseCriteria.get(:explicit_non_goals)

    assert criterion.status == :satisfied
    assert "LocalIOSParityAcceptance" in criterion.evidence
    assert "LocalIOSParityHardwareValidationPlan" in criterion.evidence
    assert "LocalIOSParityNegativeValidation" in criterion.evidence
    assert "LocalIOSParityEvidenceManifest" in criterion.evidence
    assert "LocalReleaseCandidateEvidenceReview" in criterion.evidence
  end

  test "snapshot distinguishes constrained release readiness from whole-project completion" do
    snapshot = LocalReleaseCriteria.snapshot()

    assert snapshot.mode == :advertisement_only_local_mesh
    assert snapshot.releasable_with_limitations?
    assert snapshot.satisfied_count == 5
    assert snapshot.limited_count == 2
    assert snapshot.blocked_count == 0

    assert Enum.any?(
             snapshot.notes,
             &String.contains?(&1, "not whole-project completion")
           )
  end

  test "local inbox snapshot exposes release criteria" do
    snapshot = LocalInbox.new() |> LocalInbox.snapshot()

    assert snapshot.release_criteria.mode == :advertisement_only_local_mesh
    assert snapshot.release_criteria.limited_count == 2
  end

  test "project readiness release hardening remains partial" do
    assert {:ok, item} = LocalProjectReadiness.get(:release_hardening)

    assert item.status == :partial

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "LocalReleaseCandidateEvidenceReview")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "artifact bundle task")
           )

    assert Enum.any?(
             item.current_evidence,
             &String.contains?(&1, "candidate review task")
           )

    assert Enum.any?(
             item.remaining_work,
             &String.contains?(&1, "LocalReleaseCandidateEvidenceReview")
           )
  end
end
