defmodule MeshxMobileApp.BLE.LocalHardwareValidationGates do
  @moduledoc """
  Hardware validation gates for local BLE mesh capabilities.

  This module records proof gates as data. It does not inspect attached
  hardware, run adb, parse logcat, start BLE, fetch messages, route,
  persist, ACK, retry, encrypt, or run in the background.
  """

  defmodule Gate do
    @moduledoc false

    @derive {JSON.Encoder, only: [:id, :status, :evidence, :required_evidence, :notes]}
    @enforce_keys [:id, :status, :evidence, :required_evidence, :notes]
    defstruct @enforce_keys

    @type id ::
            :android_legacy_beacon_gossip_one_hop
            | :android_full_envelope_advert_pair
            | :gatt_known_good_fetch
            | :advert_gossip_multi_hop_hardware
            | :ios_advert_only_participation

    @type status ::
            :passed
            | :partial
            | :blocked
            | :not_started

    @type t :: %__MODULE__{
            id: id(),
            status: status(),
            evidence: [binary()],
            required_evidence: [binary()],
            notes: [binary()]
          }
  end

  @gate_specs [
    %{
      id: :android_legacy_beacon_gossip_one_hop,
      status: :passed,
      evidence: [
        "/tmp/meshx-android-m59-gossip-live/summary.json",
        "/tmp/meshx-android-m26b-legacy-current/summary.json"
      ],
      required_evidence: [],
      notes: [
        "SM-T577U legacy beacon gossip was observed by SM-T390 as canonical received_message_beacon.",
        "Current SM-T577U to SM-T390 rerun reports legacy_beacon_delivery_complete=true and legacy_beacon_payload_match=true.",
        "This is one-hop beacon reference proof, not full message delivery."
      ]
    },
    %{
      id: :android_full_envelope_advert_pair,
      status: :partial,
      evidence: ["docs/android_ble_message_delivery_validation.md"],
      required_evidence: [
        "Sender and observer must both be Android devices.",
        "Observer logcat must contain canonical received_message with matching M14 envelope.",
        "summary.json must report m26_android_to_android_complete=true."
      ],
      notes: [
        "Full envelope advert path exists and Android-to-macOS proof exists.",
        "Current SM-T577U to SM-T390 rerun has two ready adb devices and observer scan readiness, but SM-T390 did not observe the SM-T577U full-envelope advert as canonical received_message."
      ]
    },
    %{
      id: :gatt_known_good_fetch,
      status: :blocked,
      evidence: [
        "docs/ble_transport_re_evaluation.md",
        "docs/ble_transport_strategy.md",
        "LocalFetchTransportValidationPlan",
        "/tmp/meshx-android-m40-current"
      ],
      required_evidence: [
        "Known-good hardware pair must pass standalone GATT connect.",
        "Service discovery and characteristic discovery must succeed.",
        "One tiny read/write must complete cleanly.",
        "Constrained fetch must retrieve and parse one full MessageEnvelope."
      ],
      notes: [
        "SM-T577U/SM-T390 fails with Android gatt_status=133 before service discovery.",
        "Current standalone GATT interop rerun still fails with status 133 in both directions after waking devices and dismissing keyguard.",
        "Until this gate passes, beacon refs cannot be resolved by real GATT fetch."
      ]
    },
    %{
      id: :advert_gossip_multi_hop_hardware,
      status: :blocked,
      evidence: [
        "apps/meshx_mobile_app/test/fixtures/advert_gossip_scenarios",
        "LocalAdvertGossipHardwareValidationPlan"
      ],
      required_evidence: [
        "Three or more hardware participants, or a controlled test rig with equivalent physical roles.",
        "At least one origin, one relay, and one observer log stream.",
        "Canonical received_message_beacon events must show hop propagation without fake delivery claims."
      ],
      notes: [
        "Replay simulator proves policy behavior.",
        "Current hardware proof covers one-hop beacon gossip only."
      ]
    },
    %{
      id: :ios_advert_only_participation,
      status: :partial,
      evidence: [
        "apps/meshx_mobile_app/lib/meshx_mobile_app/native_bridge/ios.ex",
        "artifacts/local-ble/2026-05-15-iphone13-sm-t577u/hardware/i26b-android-to-iphone-receive/summary.json",
        "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/summary.json",
        "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/android-fetch-ios-responder-rerun/summary.md",
        "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/android-aux-full-mx-ios-observe/summary.md",
        "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/android-aux-full-mx-ios-observe-rerun/summary.md",
        "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/ipad-full-beacon-android-auto-fetch-hash-cue/",
        "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/ipad-full-beacon-android-runtime-fetch-receive-only/",
        "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/aux-alternate-ios-target-check/summary.md",
        "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/external-blocker-recheck-1358/summary.md",
        "docs/ble_transport_re_evaluation.md"
      ],
      required_evidence: [
        "Android receipt of iOS-origin legacy beacon gossip if iOS beacon emission is part of the product claim.",
        "Direct full-MX extended-advert receive remains blocked until a future iOS hardware/API path surfaces AUX manufacturer data.",
        "iOS background BLE evidence if background participation is part of the product claim.",
        "Replay fixture or validation ledger must preserve every claimed canonical ingress shape."
      ],
      notes: [
        "iOS foreground legacy-beacon observe is hardware validated.",
        "Android fetch from iOS MeshxFetchGattResponder is hardware validated on SM-T577U to iPad12,1.",
        "Android receive-side hash-cued auto-fetch from the iPad MeshxFetchGattResponder is hardware validated for the explicit foreground opt-in path.",
        "Android runtime receive-only hash-cued auto-fetch is hardware validated in a default debug build with self-test sends rejected at the native send entry point.",
        "Android direct full-MX AUX emission is hardware probed and rerun on SM-T577U, but iPad12,1 did not surface the MX manufacturer data callback.",
        "Alternate iOS receiver check found the iPhone 13 unavailable, so no second iOS AUX receiver target was available in this workspace.",
        "External blocker recheck at 2026-05-17T13:58:54-0700 still found the iPhone 13 unavailable; upstream mob PR state is tracked separately in upstream-pr-recheck-1358.",
        "iOS-origin beacon emission has on-device dispatch evidence, but Android did not record a matched iPad sender hash in the archived run.",
        "Direct full-MX extended advertising remains blocked on tested iOS hardware; use MB beacon plus GATT fetch for full-envelope transfer."
      ]
    }
  ]

  @spec gates() :: [Gate.t()]
  def gates, do: Enum.map(@gate_specs, &struct!(Gate, &1))

  @spec get(Gate.id()) :: {:ok, Gate.t()} | {:error, :not_found}
  def get(id) do
    case Enum.find(gates(), &(&1.id == id)) do
      %Gate{} = gate -> {:ok, gate}
      nil -> {:error, :not_found}
    end
  end

  @spec open_gates() :: [Gate.t()]
  def open_gates, do: Enum.reject(gates(), &(&1.status == :passed))

  @spec snapshot() :: map()
  def snapshot do
    %{
      gates: gates(),
      open_gates: open_gates(),
      passed_gate_count: Enum.count(gates(), &(&1.status == :passed)),
      open_gate_count: length(open_gates()),
      notes: [
        "Replay proof and hardware proof are tracked separately.",
        "A beacon ref remains a pointer until a real resolution transport passes its gate.",
        "No blocked gate is treated as product delivery success."
      ]
    }
  end
end
