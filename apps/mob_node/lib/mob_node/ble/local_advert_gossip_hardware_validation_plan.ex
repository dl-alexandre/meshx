defmodule Mob.Node.BLE.LocalAdvertGossipHardwareValidationPlan do
  @moduledoc """
  Hardware validation plan for multi-hop advertisement gossip.

  Replay fixtures prove deterministic gossip policy, and current Android
  hardware evidence proves one-hop legacy beacon gossip. This module records
  the evidence required before MeshX can claim physical multi-hop advert
  gossip with origin, relay, and observer roles. It does not scan, advertise,
  relay, route, fetch, persist, ACK, retry, encrypt, authenticate, or run
  background work.
  """

  defmodule Gate do
    @moduledoc false

    @derive {JSON.Encoder,
             only: [
               :id,
               :status,
               :required_evidence,
               :missing_evidence,
               :blocked_claims,
               :notes
             ]}
    @enforce_keys [
      :id,
      :status,
      :required_evidence,
      :missing_evidence,
      :blocked_claims,
      :notes
    ]
    defstruct @enforce_keys

    @type status :: :blocked

    @type t :: %__MODULE__{
            id: atom(),
            status: status(),
            required_evidence: [binary()],
            missing_evidence: [binary()],
            blocked_claims: [atom()],
            notes: [binary()]
          }
  end

  @spec gates() :: [Gate.t()]
  def gates do
    [
      gate(
        :three_role_device_matrix,
        [
          "Three or more physical participants, or a controlled rig with equivalent origin, relay, and observer roles.",
          "Device model, OS/API version, BLE capability, role, adapter state, and clock/source metadata for each participant."
        ],
        [
          "Origin, relay, and observer device inventory.",
          "Capability evidence for scanning and legacy beacon advertising on every role that needs it."
        ],
        [:multi_hop_hardware_gossip, :multi_hop_hardware_delivery],
        ["Two-device one-hop beacon evidence cannot satisfy the relay role."]
      ),
      gate(
        :origin_relay_observer_capture,
        [
          "Origin log showing the initial canonical received_message_beacon or emitted legacy beacon.",
          "Relay log showing observation of the origin ref and a bounded re-advertise/gossip intent.",
          "Observer log showing receipt of the relayed ref from the relay role."
        ],
        [
          "Synchronized origin, relay, and observer logcat or equivalent capture files.",
          "Summary artifact tying all three roles to the same message_id_hash and sender_peer_hash."
        ],
        [:multi_hop_hardware_gossip, :routed_delivery],
        ["Physical hop propagation is not the same as routed delivery."]
      ),
      gate(
        :replay_normalized_fixture,
        [
          "Hardware capture normalized through the canonical replay ingress path.",
          "Replay fixture preserving origin, relay, observer, hop count, TTL, and suppression metadata."
        ],
        [
          "Replay-normalized fixture generated from the hardware run.",
          "Audit output proving the fixture matches expected multi-hop summary counts."
        ],
        [:multi_hop_hardware_gossip],
        ["Hardware logs and replay fixtures must agree before the claim can move."]
      ),
      gate(
        :ttl_and_suppression_evidence,
        [
          "Evidence that TTL/hop budget changes across the physical hop.",
          "Loop, duplicate, seen-before, and expired-ref suppression evidence from hardware or controlled rig captures."
        ],
        [
          "Hardware or rig capture for TTL decrement and duplicate suppression.",
          "Negative fixture proving repeated one-hop observations do not become multi-hop success."
        ],
        [:multi_hop_hardware_gossip, :guaranteed_delivery],
        ["TTL and suppression evidence bounds gossip; it does not create guaranteed delivery."]
      ),
      gate(
        :one_hop_negative_review,
        [
          "Regression evidence that SM-T577U to SM-T390 one-hop legacy beacon proof remains classified as one-hop only.",
          "Negative fixture proving replay-only topology and two-device hardware evidence cannot satisfy multi-hop hardware."
        ],
        [
          "Implementation-backed negative evidence for replay-as-hardware and one-hop-as-multi-hop cases.",
          "Readiness and release manifests preserving blocked multi-hop wording until physical evidence exists."
        ],
        [:multi_hop_hardware_gossip, :multi_hop_hardware_delivery],
        ["The existing one-hop success remains valuable but insufficient."]
      ),
      gate(
        :release_artifact_linkage,
        [
          "Release manifest entries linking hardware logs, replay fixture, advert gossip audit output, and operator notes.",
          "Operator wording review that describes hop propagation without claiming routing, delivery guarantee, trust, or background operation."
        ],
        [
          "Release-candidate artifact bundle for the multi-hop hardware run.",
          "Operator release-note review preserving routing, delivery, trust, and background blockers."
        ],
        [:whole_project_complete, :routed_delivery, :trusted_delivery, :background_operation],
        [
          "Multi-hop advert gossip proof closes only the physical gossip gate, not the whole project."
        ]
      )
    ]
  end

  @spec snapshot() :: map()
  def snapshot do
    gates = gates()

    %{
      plan_version: 1,
      boundary: :advert_gossip_multi_hop_hardware_validation_plan,
      current_hardware_scope: :one_hop_legacy_beacon_gossip_only,
      multi_hop_hardware_gossip_claim_allowed?: false,
      routed_delivery_claim_allowed?: false,
      guaranteed_delivery_claim_allowed?: false,
      background_operation_claim_allowed?: false,
      gate_count: length(gates),
      blocked_gate_count: Enum.count(gates, &(&1.status == :blocked)),
      gates: gates,
      blocked_claims: [
        :multi_hop_hardware_gossip,
        :multi_hop_hardware_delivery,
        :routed_delivery,
        :guaranteed_delivery,
        :background_operation,
        :whole_project_complete
      ],
      notes: [
        "Replay topology fixtures remain policy evidence, not physical hardware proof.",
        "The validated Android hardware path is one-hop legacy beacon gossip.",
        "This plan adds evidence gates only; it does not add radio behavior or relay execution."
      ]
    }
  end

  @spec json_snapshot() :: map()
  def json_snapshot do
    snapshot()
    |> JSON.encode!()
    |> JSON.decode!()
  end

  defp gate(id, required_evidence, missing_evidence, blocked_claims, notes) do
    %Gate{
      id: id,
      status: :blocked,
      required_evidence: required_evidence,
      missing_evidence: missing_evidence,
      blocked_claims: blocked_claims,
      notes: notes
    }
  end
end
