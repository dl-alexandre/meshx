defmodule MeshxMobileApp.BLE.LocalReleaseEvidenceManifest do
  @moduledoc """
  Hardware evidence manifest requirements for local BLE release candidates.

  This module projects hardware validation gates into release-candidate
  evidence requirements. It does not inspect hardware, run adb, parse
  logs, scan, advertise, fetch, route, persist, ACK, retry, encrypt, or
  run background work.
  """

  alias MeshxMobileApp.BLE.LocalHardwareValidationGates

  defmodule Entry do
    @moduledoc false

    @derive {JSON.Encoder,
             only: [
               :gate_id,
               :status,
               :required_for,
               :accepted_evidence,
               :missing_evidence,
               :notes
             ]}
    @enforce_keys [
      :gate_id,
      :status,
      :required_for,
      :accepted_evidence,
      :missing_evidence,
      :notes
    ]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            gate_id: LocalHardwareValidationGates.Gate.id(),
            status: LocalHardwareValidationGates.Gate.status(),
            required_for: [atom()],
            accepted_evidence: [binary()],
            missing_evidence: [binary()],
            notes: [binary()]
          }
  end

  @required_for %{
    android_legacy_beacon_gossip_one_hop: [
      :advert_only_local_release,
      :nearby_beacon_refs
    ],
    android_full_envelope_advert_pair: [
      :full_envelope_android_to_android_claim
    ],
    gatt_known_good_fetch: [
      :full_message_resolution_from_beacon_ref
    ],
    advert_gossip_multi_hop_hardware: [
      :multi_hop_hardware_claim,
      :routing_or_forwarding_claim
    ],
    ios_advert_only_participation: [
      :ios_parity_claim
    ]
  }

  @spec entries() :: [Entry.t()]
  def entries do
    LocalHardwareValidationGates.gates()
    |> Enum.map(&entry/1)
  end

  @spec open_entries() :: [Entry.t()]
  def open_entries, do: Enum.reject(entries(), &(&1.status == :passed))

  @spec snapshot() :: map()
  def snapshot do
    entries = entries()
    open_entries = Enum.reject(entries, &(&1.status == :passed))

    %{
      manifest_version: 1,
      evidence_boundary: :local_ble_hardware_release_evidence,
      entries: entries,
      open_entries: open_entries,
      passed_count: Enum.count(entries, &(&1.status == :passed)),
      open_count: length(open_entries),
      release_candidate_complete?: open_entries == [],
      notes: [
        "Passed gates may support only the claims listed in required_for.",
        "Open gates must remain visible in any release candidate evidence bundle.",
        "This manifest does not create hardware proof; it lists required evidence."
      ]
    }
  end

  @spec json_snapshot() :: map()
  def json_snapshot do
    snapshot()
    |> JSON.encode!()
    |> JSON.decode!()
  end

  defp entry(%LocalHardwareValidationGates.Gate{} = gate) do
    %Entry{
      gate_id: gate.id,
      status: gate.status,
      required_for: Map.fetch!(@required_for, gate.id),
      accepted_evidence: gate.evidence,
      missing_evidence: gate.required_evidence,
      notes: gate.notes
    }
  end
end
