defmodule Mob.Node.BLE.LocalFetchTransportValidationPlan do
  @moduledoc """
  Validation plan for resolving legacy beacon refs through a real transport.

  Beacon refs currently identify a message by compact hashes. Fetch
  contracts, planning, dry-run dispatch, and fake/offline fetch are in
  place, but no physical transport has retrieved and replay-parsed a full
  MessageEnvelope from a beacon ref. This module records the evidence gates
  required before MeshX can claim full message resolution from legacy
  beacons. It does not scan, advertise, connect, fetch, route, persist, ACK,
  retry, encrypt, or run background work.
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

    @type status :: :satisfied | :blocked

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
        :current_gatt_blocker_recorded,
        :satisfied,
        [
          "M40 standalone GATT interop evidence for SM-T577U and SM-T390.",
          "M66 transport re-evaluation gate documenting status 133 before service discovery."
        ],
        [],
        [:gatt_fetch_success, :full_message_resolution],
        [
          "The current Android pair is known-bad for GATT fetch; recording that blocker does not validate a fetch transport."
        ]
      ),
      gate(
        :candidate_transport_decision,
        :blocked,
        [
          "Operator decision naming the next constrained fetch transport to validate.",
          "Decision record comparing GATT, alternate BLE mechanism, or another local constrained transport."
        ],
        [
          "Known-good candidate transport decision for full-envelope retrieval.",
          "Evidence that the candidate can carry one canonical MessageEnvelope without fragmentation or routing."
        ],
        [:full_message_resolution, :transport_validated],
        [
          "Advertisement-only beacon gossip remains the validated mode until this decision is backed by hardware evidence."
        ]
      ),
      gate(
        :standalone_interop_matrix,
        :blocked,
        [
          "At least one hardware pair passing connect/setup for the selected transport.",
          "Device model, OS/API version, role, address/session id, timeout, and status logs for both directions where applicable."
        ],
        [
          "Known-good hardware pair logs for the selected transport.",
          "Failure logs for unsupported pairs kept separate from success evidence."
        ],
        [:known_good_transport, :full_message_resolution],
        [
          "A passing standalone interop harness is required before MeshX fetch logic can be blamed or trusted."
        ]
      ),
      gate(
        :constrained_fetch_exchange,
        :blocked,
        [
          "One requester, one responder, one BeaconFetchRequest, and one full MessageEnvelope response.",
          "No retries, routing, ACKs, persistence, crypto, background service, or fragmentation in the proof path."
        ],
        [
          "Hardware logs showing request emission, responder lookup, response emission, and requester receipt.",
          "Summary artifact tying request_id and message_id_hash to the retrieved envelope."
        ],
        [:full_message_resolution, :message_delivery],
        [
          "A fetch exchange can prove resolution only; it is still not routed or guaranteed delivery."
        ]
      ),
      gate(
        :canonical_replay_resolution,
        :blocked,
        [
          "Retrieved envelope must parse through the canonical replay/ReceivedMessage path.",
          "Resolved envelope hash must match message_id_hash and sender_peer_hash from the original BeaconRef."
        ],
        [
          "Replay-normalized fixture generated from the hardware fetch capture.",
          "Hash-match evidence proving the beacon ref resolved to the retrieved envelope."
        ],
        [:resolved_message, :trusted_message],
        ["Canonical parsing and hash matching do not prove authorship or trust by themselves."]
      ),
      gate(
        :negative_failure_matrix,
        :blocked,
        [
          "Malformed beacon, unknown envelope, hash mismatch, responder unavailable, timeout, and unsupported transport cases.",
          "Evidence that every failed case remains unresolved instead of becoming fake delivery."
        ],
        [
          "Implementation-backed negative fixtures for selected transport failures.",
          "Release audit evidence that unresolved refs stay visible as pointers."
        ],
        [:fake_success, :guaranteed_delivery],
        ["Failed fetches must remain auditable unresolved refs."]
      ),
      gate(
        :release_artifact_linkage,
        :blocked,
        [
          "Readiness, release manifest, hardware evidence manifest, and operator notes for the successful transport proof.",
          "Explicit wording that beacon resolution is not routing, background operation, or trusted delivery."
        ],
        [
          "Release-candidate artifact bundle linking transport logs, replay fixture, and operator wording review.",
          "Completion audit update after all transport gates pass."
        ],
        [:whole_project_complete, :trusted_delivery, :routed_delivery],
        [
          "Whole-project completion remains blocked until every project objective closes, not only fetch transport."
        ]
      )
    ]
  end

  @spec snapshot() :: map()
  def snapshot do
    gates = gates()

    %{
      plan_version: 1,
      boundary: :full_message_resolution_transport_validation_plan,
      current_validated_fetch_transport: :none,
      current_known_bad_pair: %{
        sender_or_responder: "SM-T577U",
        observer_or_requester: "SM-T390",
        failure: :android_gatt_status_133_before_service_discovery
      },
      full_message_resolution_claim_allowed?: false,
      beacon_refs_resolvable_by_real_transport?: false,
      gatt_fetch_enabled_by_default?: false,
      gate_count: length(gates),
      satisfied_gate_count: Enum.count(gates, &(&1.status == :satisfied)),
      blocked_gate_count: Enum.count(gates, &(&1.status == :blocked)),
      gates: gates,
      blocked_claims: [
        :full_message_resolution,
        :known_good_transport,
        :message_delivery,
        :trusted_delivery,
        :whole_project_complete
      ],
      notes: [
        "Fake/offline fetch remains contract evidence, not hardware transport proof.",
        "GATT remains experimental and disabled until a known-good hardware pair passes standalone interop and constrained fetch.",
        "A beacon ref remains a pointer until canonical replay confirms the retrieved envelope matches it."
      ]
    }
  end

  @spec json_snapshot() :: map()
  def json_snapshot do
    snapshot()
    |> JSON.encode!()
    |> JSON.decode!()
  end

  defp gate(id, status, required_evidence, missing_evidence, blocked_claims, notes) do
    %Gate{
      id: id,
      status: status,
      required_evidence: required_evidence,
      missing_evidence: missing_evidence,
      blocked_claims: blocked_claims,
      notes: notes
    }
  end
end
