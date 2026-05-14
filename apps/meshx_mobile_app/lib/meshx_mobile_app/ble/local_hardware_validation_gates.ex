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
      status: :not_started,
      evidence: ["apps/meshx_mobile_app/lib/meshx_mobile_app/native_bridge/ios.ex"],
      required_evidence: [
        "iOS bridge must emit or observe canonical advert-only beacon/full-envelope events.",
        "Hardware capture must show iOS participation in received_message_beacon or received_message.",
        "Replay fixture must preserve the same canonical ingress shape."
      ],
      notes: [
        "iOS bridge shell exists.",
        "iOS advert-only beacon/gossip participation is not implemented or hardware validated."
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
