defmodule MeshxMobileApp.BLE.LocalReleaseCriteria do
  @moduledoc """
  Release criteria for the currently validated advertisement-only local mode.

  This module separates a constrained advert-only local release from
  whole-project completion. It records which criteria are satisfied,
  which are explicitly limited, and which remain blocked. It does not
  run checks, touch hardware, scan, advertise, fetch, route, persist,
  ACK, retry, encrypt, or run background work.
  """

  defmodule Criterion do
    @moduledoc false

    @enforce_keys [:id, :status, :evidence, :limitations, :notes]
    defstruct @enforce_keys

    @type id ::
            :advert_only_profile
            | :legacy_beacon_observation
            | :full_envelope_observation
            | :nearby_messages_surface
            | :durable_snapshot_boundary
            | :release_audit_artifacts
            | :explicit_non_goals

    @type status :: :satisfied | :limited | :blocked

    @type t :: %__MODULE__{
            id: id(),
            status: status(),
            evidence: [binary()],
            limitations: [binary()],
            notes: [binary()]
          }
  end

  @criteria [
    %{
      id: :advert_only_profile,
      status: :satisfied,
      evidence: ["AdvertOnlyTransportProfile", "LocalInbox.snapshot/1"],
      limitations: [
        "No GATT fetch.",
        "No ACKs, retries, routing, guaranteed delivery, or background service."
      ],
      notes: ["Advertisement-only local mesh is the current validated mode."]
    },
    %{
      id: :legacy_beacon_observation,
      status: :satisfied,
      evidence: [
        "/tmp/meshx-android-m59-gossip-live/summary.json",
        "LocalHardwareValidationGates"
      ],
      limitations: [
        "One-hop Android legacy beacon proof only.",
        "Beacon refs remain pointers, not full message delivery."
      ],
      notes: ["Old Android can participate through compact beacon refs."]
    },
    %{
      id: :full_envelope_observation,
      status: :limited,
      evidence: ["docs/android_ble_message_delivery_validation.md"],
      limitations: [
        "Android-to-macOS proof exists, but exact Android-to-Android full-envelope proof is incomplete.",
        "Full-envelope adverts require capability-proven hardware."
      ],
      notes: ["Full ReceivedMessage remains distinct from legacy beacon refs."]
    },
    %{
      id: :nearby_messages_surface,
      status: :satisfied,
      evidence: [
        "LocalInboxProductSurface",
        "LocalInboxNativeSurface",
        "LocalInboxStateCopy",
        "LocalInboxUxAcceptance",
        "LocalInboxUxValidationPlan",
        "LocalInboxUxEvidenceManifest",
        "LocalInboxNativeSurface summary_line / empty_label",
        "MeshxMobileApp.HomeScreen",
        "LocalInboxPresenter",
        "LocalInboxQuery",
        "LocalInboxActionSummary"
      ],
      limitations: [
        "LocalInboxUxAcceptance keeps production UX claims blocked until on-device validation is attached.",
        "Mob Nearby Messages controls are wired to the native surface model, but still need on-device UX validation before production release.",
        "Visual density may need refinement for production use."
      ],
      notes: ["The app can show messages seen nearby with state, trust, and resolution blockers."]
    },
    %{
      id: :durable_snapshot_boundary,
      status: :limited,
      evidence: [
        "LocalInboxStore",
        "LocalInboxPersistenceProfile",
        "LocalInboxPersistenceLifecycle",
        "LocalPersistenceNegativeValidation",
        "LocalInboxStore.list/1",
        "LocalInboxStore.prune_expired/1",
        "LocalInboxPersistenceOperator",
        "LocalPersistenceAcceptance",
        "LocalPersistenceProductionLifecyclePlan",
        "LocalPersistenceEvidenceManifest",
        "mix meshx.mobile.local_persistence.lifecycle_plan --json --out <path>",
        "Session persist_local_inbox? / restore_local_inbox?"
      ],
      limitations: [
        "LocalPersistenceAcceptance keeps default lifecycle persistence blocked until migration, scheduled cleanup, background-safe write, and on-device restore evidence exist.",
        "LocalPersistenceProductionLifecyclePlan records the remaining default decision, migration, cleanup, writer, restore, and release evidence gates.",
        "Persistence lifecycle decision keeps durable snapshots explicit opt-in and not the default app lifecycle.",
        "No migrations, scheduled cleanup worker, sync, or background-safe writer exists."
      ],
      notes: ["Durable local inbox snapshots are available for policy-approved read models."]
    },
    %{
      id: :release_audit_artifacts,
      status: :satisfied,
      evidence: [
        "mix meshx.mobile.advert_gossip.audit",
        "mix meshx.mobile.local_readiness.audit --allow-open --json",
        "mix meshx.mobile.local_readiness.audit --allow-open --out <path>",
        "mix meshx.mobile.remaining_items.audit --json --out <path>",
        "mix meshx.mobile.remaining_items.audit | tee <path>",
        "mix meshx.mobile.local_lifecycle.validation_plan --json --out <path>",
        "mix meshx.mobile.local_lifecycle.evidence --json --out <path>",
        "mix meshx.mobile.local_routing.validation_plan --json --out <path>",
        "mix meshx.mobile.local_security.validation_plan --json --out <path>",
        "mix meshx.mobile.local_release.manifest --json --out <path>",
        "mix meshx.mobile.local_release.recent_evidence --json --out <path>",
        "LocalFocusedRemainingItemsAudit",
        "LocalReleaseRecentEvidenceInventory",
        "LocalReleaseCandidateEvidenceReview"
      ],
      limitations: [
        "Readiness audit reports open blockers; it does not convert partial work into completion.",
        "Focused remaining-items audit keeps direct full-MX AUX and upstream patch migration rows incomplete until their closure evidence exists.",
        "Recent-evidence inventory preserves AUX checklist and upstream handoff pointers without allowing completion claims."
      ],
      notes: ["Release/status outputs are machine-readable and archiveable."]
    },
    %{
      id: :explicit_non_goals,
      status: :satisfied,
      evidence: [
        "LocalProjectReadiness",
        "LocalFetchTransportValidationPlan",
        "LocalFullMessageResolutionEvidenceManifest",
        "LocalAdvertGossipHardwareValidationPlan",
        "LocalMultiHopHardwareEvidenceManifest",
        "LocalPersistenceAcceptance",
        "LocalTrustPolicy",
        "LocalSecurityAcceptance",
        "LocalSecurityPeerEnrollment",
        "LocalSecurityAuthorshipProof",
        "LocalSecurityPeerIdentityBinding",
        "LocalSecurityReplayProtection",
        "LocalSecurityReplayLifecyclePolicy",
        "LocalSecurityReplayLifecycleValidation",
        "LocalSecurityTrustedMessageDecision",
        "LocalSecurityCanonicalReplayDecision",
        "LocalSecurityOperatorTrustPolicy",
        "LocalSecurityTrustLifecyclePlan",
        "LocalSecurityTrustLifecycleValidation",
        "LocalSecurityBeaconAuthentication",
        "LocalSecurityCryptoNegativeValidation",
        "LocalSecurityFixtureAudit",
        "LocalSecurityReleaseEvidenceReview",
        "LocalSecurityEvidenceManifest",
        "LocalSecurityTrustModel",
        "LocalSecurityIdentityContract",
        "LocalSecurityIdentityProofPlan",
        "LocalSecurityIdentityValidationPlan",
        "LocalSecurityIdentityNegativeValidation",
        "mix meshx.mobile.local_security.validation_plan --json --out <path>",
        "LocalPersistenceNegativeValidation",
        "LocalRoutingPolicy",
        "LocalRoutingAcceptance",
        "LocalRoutingContract",
        "LocalRoutingProofPlan",
        "LocalRoutingHardwareValidationPlan",
        "LocalRoutingTable",
        "LocalRoutingNegativeValidation",
        "LocalRoutingEvidenceManifest",
        "mix meshx.mobile.local_routing.validation_plan --json --out <path>",
        "LocalLifecyclePolicy",
        "LocalLifecycleAcceptance",
        "LocalBackgroundLifecycleContract",
        "LocalLifecycleProofPlan",
        "LocalLifecycleHardwareValidationPlan",
        "LocalLifecycleNegativeValidation",
        "LocalLifecycleEvidenceManifest",
        "LocalIOSParityPolicy",
        "LocalIOSParityAcceptance",
        "LocalIOSParityContract",
        "LocalIOSParityProofPlan",
        "LocalIOSParityHardwareValidationPlan",
        "LocalIOSParityNegativeValidation",
        "LocalIOSParityEvidenceManifest",
        "mix meshx.mobile.local_release.artifact_bundle --json --out <path>",
        "mix meshx.mobile.local_release.candidate_review --input <path> --json --out <path>",
        "LocalReleaseCandidateEvidenceReview",
        "LocalProjectCompletionAudit"
      ],
      limitations: [
        "Real fetch transport, multi-hop hardware proof, crypto, routing, background lifecycle, and iOS parity remain open."
      ],
      notes: ["The release boundary must not claim whole-project completion."]
    }
  ]

  @spec criteria() :: [Criterion.t()]
  def criteria, do: Enum.map(@criteria, &struct!(Criterion, &1))

  @spec get(Criterion.id()) :: {:ok, Criterion.t()} | {:error, :not_found}
  def get(id) do
    case Enum.find(criteria(), &(&1.id == id)) do
      %Criterion{} = criterion -> {:ok, criterion}
      nil -> {:error, :not_found}
    end
  end

  @spec satisfied() :: [Criterion.t()]
  def satisfied, do: Enum.filter(criteria(), &(&1.status == :satisfied))

  @spec limited() :: [Criterion.t()]
  def limited, do: Enum.filter(criteria(), &(&1.status == :limited))

  @spec blocked() :: [Criterion.t()]
  def blocked, do: Enum.filter(criteria(), &(&1.status == :blocked))

  @spec snapshot() :: map()
  def snapshot do
    %{
      mode: :advertisement_only_local_mesh,
      releasable_with_limitations?: blocked() == [],
      criteria: criteria(),
      satisfied_count: length(satisfied()),
      limited_count: length(limited()),
      blocked_count: length(blocked()),
      notes: [
        "This is a release boundary for the validated advert-only local mode, not whole-project completion.",
        "Release wording must say messages seen nearby, not guaranteed delivery.",
        "Readiness blockers remain visible through LocalProjectReadiness."
      ]
    }
  end
end
