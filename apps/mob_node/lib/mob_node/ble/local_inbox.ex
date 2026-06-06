defmodule Mob.Node.BLE.LocalInbox do
  @moduledoc """
  Unified advertisement-only local inbox.

  This module lets MeshX show messages seen nearby using only canonical
  BLE advertisement observations. Full-envelope advertisements become
  full local message entries; legacy beacons remain unresolved references.

  No GATT, routing, persistence, ACKs, retries, crypto, or background
  service behavior is introduced here.
  """

  alias Mob.Node.BLE.{
    AdvertOnlyTransportProfile,
    BeaconInbox,
    FullEnvelopeInbox,
    LocalBackgroundLifecycleContract,
    LocalHardwareValidationGates,
    LocalInboxResolution,
    LocalInboxTrust,
    LocalInboxUxAcceptance,
    LocalInboxView,
    LocalIOSParityContract,
    LocalIOSParityAcceptance,
    LocalIOSParityPolicy,
    LocalLifecycleAcceptance,
    LocalLifecyclePolicy,
    LocalPlatformParity,
    LocalPersistenceAcceptance,
    LocalProjectReadiness,
    LocalReleaseCriteria,
    LocalRoutingAcceptance,
    LocalRoutingContract,
    LocalRoutingPolicy,
    LocalSecurityIdentityContract,
    LocalSecurityAcceptance,
    LocalSecurityTrustModel,
    LocalTrustPolicy,
    LocalTransportLifecycleProfile
  }

  defstruct beacon_inbox: BeaconInbox.new(),
            full_envelope_inbox: FullEnvelopeInbox.new(),
            transport_profile: AdvertOnlyTransportProfile.advert_only(),
            lifecycle_profile: LocalTransportLifecycleProfile.foreground_manual()

  @type t :: %__MODULE__{
          beacon_inbox: BeaconInbox.t(),
          full_envelope_inbox: FullEnvelopeInbox.t(),
          transport_profile: AdvertOnlyTransportProfile.t(),
          lifecycle_profile: LocalTransportLifecycleProfile.t()
        }

  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      beacon_inbox: Keyword.get(opts, :beacon_inbox, BeaconInbox.new()),
      full_envelope_inbox: Keyword.get(opts, :full_envelope_inbox, FullEnvelopeInbox.new()),
      transport_profile:
        Keyword.get(opts, :transport_profile, AdvertOnlyTransportProfile.advert_only()),
      lifecycle_profile:
        Keyword.get(opts, :lifecycle_profile, LocalTransportLifecycleProfile.foreground_manual())
    }
  end

  @spec ingest(t(), term()) :: t()
  def ingest(%__MODULE__{} = inbox, event) do
    %{
      inbox
      | beacon_inbox: BeaconInbox.ingest(inbox.beacon_inbox, event),
        full_envelope_inbox: FullEnvelopeInbox.ingest(inbox.full_envelope_inbox, event)
    }
  end

  @spec ingest_many(t(), Enumerable.t()) :: t()
  def ingest_many(%__MODULE__{} = inbox, events) do
    Enum.reduce(events, inbox, &ingest(&2, &1))
  end

  @doc """
  Lightweight snapshot for live UI (home screen, session assigns).

  Skips release-audit modules that run crypto fixtures and can crash or
  stall on device OTP. Use `snapshot/1` in tests and audit tasks.
  """
  @spec product_snapshot(t()) :: map()
  def product_snapshot(%__MODULE__{} = inbox) do
    snapshot = %{
      transport_profile: AdvertOnlyTransportProfile.snapshot(inbox.transport_profile),
      lifecycle_profile: LocalTransportLifecycleProfile.snapshot(inbox.lifecycle_profile),
      full_messages: FullEnvelopeInbox.snapshot(inbox.full_envelope_inbox),
      unresolved_beacon_refs: BeaconInbox.snapshot(inbox.beacon_inbox),
      capability_notes: inbox.transport_profile.capability_notes,
      security_acceptance: %{
        acceptance_version: 1,
        boundary: :current_unsigned_local_ble_security,
        gates: [],
        satisfied_count: 0,
        blocked_count: 0,
        authenticated_peer_identity_claim_allowed?: false,
        trusted_message_claim_allowed?: false,
        trusted_delivery_claim_allowed?: false,
        replay_protection_claim_allowed?: false,
        blocked_claims: [],
        notes: ["UI product snapshot; audit gates omitted on device."]
      }
    }

    snapshot = Map.put(snapshot, :nearby_messages, LocalInboxView.nearby_messages(snapshot))
    snapshot = Map.put(snapshot, :trust_evidence, LocalInboxTrust.classify_snapshot(snapshot))
    snapshot = Map.put(snapshot, :trust_policy, LocalTrustPolicy.snapshot(snapshot))
    snapshot = Map.put(snapshot, :resolution_statuses, LocalInboxResolution.statuses(snapshot))

    Map.put(snapshot, :ux_acceptance, %{acceptance_version: 1, notes: ["UI product snapshot"]})
  end

  @spec snapshot(t()) :: map()
  def snapshot(%__MODULE__{} = inbox) do
    snapshot = %{
      transport_profile: AdvertOnlyTransportProfile.snapshot(inbox.transport_profile),
      lifecycle_profile: LocalTransportLifecycleProfile.snapshot(inbox.lifecycle_profile),
      lifecycle_acceptance: LocalLifecycleAcceptance.snapshot(inbox.lifecycle_profile),
      lifecycle_policy: LocalLifecyclePolicy.snapshot(),
      background_lifecycle_contract: LocalBackgroundLifecycleContract.snapshot(),
      platform_parity: LocalPlatformParity.snapshot(),
      ios_parity_acceptance: LocalIOSParityAcceptance.snapshot(),
      ios_parity_contract: LocalIOSParityContract.snapshot(),
      ios_parity_policy: LocalIOSParityPolicy.snapshot(),
      hardware_validation_gates: LocalHardwareValidationGates.snapshot(),
      project_readiness: LocalProjectReadiness.snapshot(),
      persistence_acceptance: LocalPersistenceAcceptance.snapshot(),
      release_criteria: LocalReleaseCriteria.snapshot(),
      routing_acceptance: LocalRoutingAcceptance.snapshot(),
      routing_contract: LocalRoutingContract.snapshot(),
      routing_policy: LocalRoutingPolicy.snapshot(),
      security_identity_contract: LocalSecurityIdentityContract.snapshot(),
      security_trust_model: LocalSecurityTrustModel.snapshot(),
      full_messages: FullEnvelopeInbox.snapshot(inbox.full_envelope_inbox),
      unresolved_beacon_refs: BeaconInbox.snapshot(inbox.beacon_inbox),
      capability_notes: inbox.transport_profile.capability_notes
    }

    snapshot = Map.put(snapshot, :nearby_messages, LocalInboxView.nearby_messages(snapshot))

    snapshot = Map.put(snapshot, :trust_evidence, LocalInboxTrust.classify_snapshot(snapshot))

    snapshot = Map.put(snapshot, :trust_policy, LocalTrustPolicy.snapshot(snapshot))
    snapshot = Map.put(snapshot, :security_acceptance, LocalSecurityAcceptance.snapshot(snapshot))

    snapshot = Map.put(snapshot, :resolution_statuses, LocalInboxResolution.statuses(snapshot))

    Map.put(snapshot, :ux_acceptance, LocalInboxUxAcceptance.snapshot(snapshot))
  end
end
