defmodule MeshxMobileApp.BLE.LocalIOSParityProofPlan do
  @moduledoc """
  Proof plan for future iOS advertisement-only local mesh parity.

  Android has validated legacy beacon observation/gossip evidence. iOS has
  a bridge shell and shared canonical ingress contract, but no advert-only
  implementation or hardware proof. This module maps each open iOS parity
  requirement to implementation gates and validation evidence. It does not
  touch native code, scan, advertise, fetch, route, persist, ACK, retry,
  encrypt, or run background work.
  """

  alias MeshxMobileApp.BLE.LocalIOSParityContract

  defmodule Gate do
    @moduledoc false

    @derive {JSON.Encoder,
             only: [
               :requirement_id,
               :status,
               :implementation_gates,
               :validation_evidence,
               :blocked_claims,
               :notes
             ]}
    @enforce_keys [
      :requirement_id,
      :status,
      :implementation_gates,
      :validation_evidence,
      :blocked_claims,
      :notes
    ]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            requirement_id: LocalIOSParityContract.Requirement.id(),
            status: :planned | :hardware_blocked,
            implementation_gates: [atom()],
            validation_evidence: [binary()],
            blocked_claims: [atom()],
            notes: [binary()]
          }
  end

  @proof_gates %{
    canonical_ingress: %{
      status: :planned,
      implementation_gates: [
        :ios_v1_wire_event_emission,
        :bridge_protocol_normalization,
        :received_message_beacon_mapping,
        :received_message_mapping,
        :legacy_tuple_retirement_plan
      ],
      validation_evidence: [
        "Fixture proving iOS bridge maps native events through BridgeProtocol.",
        "Replay fixture with canonical received_message_beacon shape.",
        "Replay fixture with canonical received_message shape when full-envelope participation exists."
      ],
      blocked_claims: [:ios_hardware_participation, :ios_advert_only_validation],
      notes: ["Shared event contracts are necessary but not hardware proof."]
    },
    legacy_beacon_observe: %{
      status: :hardware_blocked,
      implementation_gates: [
        :ios_scanner_implementation,
        :legacy_beacon_decode,
        :canonical_received_message_beacon_event,
        :device_model_and_ios_version_capture,
        :replay_normalized_fixture
      ],
      validation_evidence: [
        "iOS hardware log showing observed legacy beacon advertisement.",
        "Canonical received_message_beacon event with matching beacon hash fields.",
        "Replay-normalized fixture or validation ledger with iOS model and version."
      ],
      blocked_claims: [:ios_legacy_beacon_observed, :ios_advert_only_participation],
      notes: ["Android SM-T390 observation proof cannot be reused as iOS proof."]
    },
    legacy_beacon_gossip: %{
      status: :planned,
      implementation_gates: [
        :ios_legacy_beacon_dispatcher,
        :compact_beacon_payload_encoder,
        :adapter_boundary_isolation,
        :observer_capture,
        :audit_summary
      ],
      validation_evidence: [
        "iOS emitted compact legacy beacon/gossip payload.",
        "Another MeshX-capable observer captured canonical received_message_beacon.",
        "Audit summary proving beacon gossip without full-message delivery claims."
      ],
      blocked_claims: [:ios_legacy_beacon_gossip, :ios_one_hop_gossip_hardware_proof],
      notes: ["No iOS legacy beacon gossip dispatcher exists today."]
    },
    full_envelope_advert: %{
      status: :hardware_blocked,
      implementation_gates: [
        :ios_ble_capability_probe,
        :full_envelope_payload_budget_check,
        :m14_envelope_encode_or_decode,
        :canonical_received_message_event,
        :capability_proven_hardware_pair
      ],
      validation_evidence: [
        "Capability probe showing iOS hardware can emit or observe the full envelope advert.",
        "Observer log containing canonical received_message with matching M14 envelope bytes.",
        "Negative evidence preserved when hardware cannot support full-envelope adverts."
      ],
      blocked_claims: [:ios_full_envelope_advert, :ios_full_message_observation],
      notes: ["Full-envelope adverts remain hardware capability dependent."]
    },
    hardware_replay_fixture: %{
      status: :hardware_blocked,
      implementation_gates: [
        :raw_ios_hardware_capture,
        :device_model_and_ios_version_metadata,
        :canonical_jsonl_fixture,
        :replay_test_coverage,
        :validation_ledger_reference
      ],
      validation_evidence: [
        "Committed iOS hardware JSONL fixture or linked validation ledger.",
        "Replay test proving fixture normalizes through the same canonical ingress path.",
        "Artifact metadata including iOS device model, iOS version, and capture command."
      ],
      blocked_claims: [:ios_hardware_replay_fixture, :ios_parity_claim],
      notes: ["Replay determinism is the standard ingress proof for future iOS parity work."]
    }
  }

  @spec gates() :: [Gate.t()]
  def gates do
    LocalIOSParityContract.open_requirements()
    |> Enum.map(&gate/1)
  end

  @spec get(LocalIOSParityContract.Requirement.id()) :: {:ok, Gate.t()} | {:error, :not_found}
  def get(requirement_id) do
    case Enum.find(gates(), &(&1.requirement_id == requirement_id)) do
      %Gate{} = gate -> {:ok, gate}
      nil -> {:error, :not_found}
    end
  end

  @spec snapshot() :: map()
  def snapshot do
    gates = gates()

    %{
      plan_version: 1,
      proof_boundary: :future_ios_advert_only_parity,
      gates: gates,
      open_gate_count: length(gates),
      hardware_blocked_count: Enum.count(gates, &(&1.status == :hardware_blocked)),
      ios_participation_claims_allowed?: false,
      notes: [
        "Every iOS parity gate is planned or hardware-blocked, not implemented.",
        "Android hardware evidence cannot satisfy iOS parity gates.",
        "iOS advert-only participation claims stay blocked until implementation and replay-normalized hardware evidence exist."
      ]
    }
  end

  @spec json_snapshot() :: map()
  def json_snapshot do
    snapshot()
    |> JSON.encode!()
    |> JSON.decode!()
  end

  defp gate(%LocalIOSParityContract.Requirement{id: id}) do
    data = Map.fetch!(@proof_gates, id)

    %Gate{
      requirement_id: id,
      status: data.status,
      implementation_gates: data.implementation_gates,
      validation_evidence: data.validation_evidence,
      blocked_claims: data.blocked_claims,
      notes: data.notes
    }
  end
end
