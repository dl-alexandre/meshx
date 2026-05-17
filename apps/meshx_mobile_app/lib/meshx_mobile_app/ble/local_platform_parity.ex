defmodule MeshxMobileApp.BLE.LocalPlatformParity do
  @moduledoc """
  Platform parity matrix for advertisement-only local mesh behavior.

  This is an evidence ledger, not a transport implementation. It records
  which local BLE capabilities have Android hardware proof, which iOS
  paths have hardware proof or remain unvalidated, and which behaviors remain
  explicitly blocked. It does not touch native code, scan, advertise,
  fetch, route, persist, ACK, retry, encrypt, or run in the background.
  """

  defmodule Entry do
    @moduledoc false

    @enforce_keys [:platform, :capability, :status, :evidence, :notes]
    defstruct @enforce_keys

    @type platform :: :android | :ios

    @type capability ::
            :legacy_beacon_observe
            | :legacy_beacon_gossip
            | :full_envelope_advert
            | :gatt_fetch
            | :background_ble

    @type status ::
            :hardware_validated
            | :capability_proven_limited
            | :contract_only
            | :implemented_unvalidated
            | :blocked_current_hardware
            | :not_implemented
            | :not_validated

    @type t :: %__MODULE__{
            platform: platform(),
            capability: capability(),
            status: status(),
            evidence: [binary()],
            notes: [binary()]
          }
  end

  @entry_specs [
    %{
      platform: :android,
      capability: :legacy_beacon_observe,
      status: :hardware_validated,
      evidence: [
        "/tmp/meshx-android-m26b-legacy/summary.json",
        "/tmp/meshx-android-m59-gossip-live/summary.json"
      ],
      notes: [
        "SM-T390 observed canonical received_message_beacon events.",
        "Legacy beacon observation is not full message delivery."
      ]
    },
    %{
      platform: :android,
      capability: :legacy_beacon_gossip,
      status: :hardware_validated,
      evidence: ["/tmp/meshx-android-m59-gossip-live/summary.json"],
      notes: [
        "SM-T577U emitted legacy beacon gossip observed by SM-T390.",
        "One-hop hardware proof only; no three-device multi-hop proof."
      ]
    },
    %{
      platform: :android,
      capability: :full_envelope_advert,
      status: :capability_proven_limited,
      evidence: ["docs/android_ble_message_delivery_validation.md"],
      notes: [
        "Full envelope advertisement path exists for capability-proven hardware.",
        "SM-T390 did not observe SM-T577U extended adverts."
      ]
    },
    %{
      platform: :android,
      capability: :gatt_fetch,
      status: :blocked_current_hardware,
      evidence: ["docs/ble_transport_re_evaluation.md", "docs/ble_transport_strategy.md"],
      notes: [
        "SM-T577U/SM-T390 failed standalone GATT before service discovery with status 133.",
        "GATT fetch remains experimental and disabled by default."
      ]
    },
    %{
      platform: :android,
      capability: :background_ble,
      status: :not_implemented,
      evidence: [
        "apps/meshx_mobile_app/lib/meshx_mobile_app/ble/local_transport_lifecycle_profile.ex"
      ],
      notes: ["No Android foreground service or background BLE lifecycle is implemented."]
    },
    %{
      platform: :ios,
      capability: :legacy_beacon_observe,
      status: :hardware_validated,
      evidence: [
        "meshx_mobile/Sources/MeshxMobile/BLE.swift",
        "apps/meshx_mobile_app/ios/MeshxBLEBridge.swift",
        "apps/meshx_mobile_app/ios/meshx_ble_nif.m",
        "artifacts/local-ble/2026-05-15-iphone13-sm-t577u/hardware/i26b-android-to-iphone-receive/summary.json"
      ],
      notes: [
        "iOS foreground scanner decodes MeshX legacy beacon manufacturer advertisements into canonical received_message_beacon wire maps.",
        "iPhone 13 hardware observed Android SM-T577U legacy beacons on 2026-05-15.",
        "This is beacon/ref observation proof only; iOS beacon gossip and direct full-envelope adverts remain separate claims."
      ]
    },
    %{
      platform: :ios,
      capability: :legacy_beacon_gossip,
      status: :not_implemented,
      evidence: ["apps/meshx_mobile_app/lib/meshx_mobile_app/native_bridge/ios.ex"],
      notes: ["No iOS legacy beacon gossip dispatcher or hardware proof is recorded."]
    },
    %{
      platform: :ios,
      capability: :full_envelope_advert,
      status: :blocked_current_hardware,
      evidence: [
        "docs/BLE_BRIDGE.md#extended-advertising-aux-delivery-limitation",
        "apps/meshx_mobile_app/lib/meshx_mobile_app/ble/bridge_protocol.ex"
      ],
      notes: [
        "Canonical receive contract is shared and bridge code is wired.",
        "Tested iOS hardware did not surface non-Apple AUX_ADV_IND manufacturer data to CoreBluetooth."
      ]
    },
    %{
      platform: :ios,
      capability: :gatt_fetch,
      status: :not_validated,
      evidence: ["docs/ble_transport_re_evaluation.md"],
      notes: ["No known-good iOS GATT fetch pair has passed the M66 gate."]
    },
    %{
      platform: :ios,
      capability: :background_ble,
      status: :not_implemented,
      evidence: [
        "apps/meshx_mobile_app/lib/meshx_mobile_app/ble/local_transport_lifecycle_profile.ex"
      ],
      notes: ["No iOS background BLE behavior is implemented."]
    }
  ]

  @spec entries() :: [Entry.t()]
  def entries, do: Enum.map(@entry_specs, &struct!(Entry, &1))

  @spec for_platform(Entry.platform()) :: [Entry.t()]
  def for_platform(platform), do: Enum.filter(entries(), &(&1.platform == platform))

  @spec get(Entry.platform(), Entry.capability()) :: {:ok, Entry.t()} | {:error, :not_found}
  def get(platform, capability) do
    case Enum.find(entries(), &(&1.platform == platform and &1.capability == capability)) do
      %Entry{} = entry -> {:ok, entry}
      nil -> {:error, :not_found}
    end
  end

  @spec blockers() :: [Entry.t()]
  def blockers do
    Enum.filter(
      entries(),
      &(&1.status in [:blocked_current_hardware, :not_implemented, :not_validated])
    )
  end

  @spec snapshot() :: map()
  def snapshot do
    %{
      entries: entries(),
      blockers: blockers(),
      notes: [
        "Android legacy beacon observe/gossip has hardware proof.",
        "iOS advert-only beacon/gossip parity is not implemented or hardware validated.",
        "GATT fetch remains gated by known-good hardware validation."
      ]
    }
  end
end
