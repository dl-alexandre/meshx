defmodule Mob.Node.BLE.LocalFullMessageResolutionEvidenceManifest do
  @moduledoc """
  Machine-readable full-message resolution evidence manifest.

  The manifest packages the current legacy beacon resolution contracts,
  fetch request/planning/offline transport evidence, and real transport
  validation gates. It is an artifact shape only. It does not open BLE
  connections, perform GATT fetch, scan, advertise, route, persist, ACK,
  retry, encrypt, authenticate, fragment, or run background work.
  """

  alias Mob.Node.BLE.{
    LocalFetchTransportValidationPlan,
    LocalFullMessageResolutionEvidenceReview,
    LocalKnownGoodTransportEvidenceReview
  }

  @required_commands [
    "mix mob.node.local_full_resolution.evidence --json --out <path>",
    "mix mob.node.local_full_resolution.transport_review --template --out <path>",
    "mix mob.node.local_full_resolution.transport_review --input <path> --json --out <path>",
    "mix mob.node.local_known_good_transport.review --template --out <path>",
    "mix mob.node.local_known_good_transport.review --input <path> --json --out <path>",
    "mix test apps/mob_node/test/mob_node/ble/beacon_resolver_test.exs",
    "mix test apps/mob_node/test/mob_node/ble/beacon_fetch_request_test.exs",
    "mix test apps/mob_node/test/mob_node/ble/beacon_fetch_pipeline_test.exs",
    "mix test apps/mob_node/test/mob_node/ble/beacon_fetch_transport_test.exs",
    "mix test apps/mob_node/test/mob_node/ble/local_fetch_transport_validation_plan_test.exs",
    "mix test apps/mob_node/test/mob_node/ble/local_full_message_resolution_evidence_manifest_test.exs",
    "mix test apps/mob_node/test/mob_node/ble/local_full_message_resolution_evidence_review_test.exs",
    "mix test apps/mob_node/test/mob_node/ble/local_known_good_transport_evidence_review_test.exs",
    "mix test apps/mob_node/test/mix/tasks/mob_node_local_full_resolution_evidence_test.exs",
    "mix test apps/mob_node/test/mix/tasks/mob_node_local_full_resolution_transport_review_test.exs",
    "mix test apps/mob_node/test/mix/tasks/mob_node_local_known_good_transport_review_test.exs"
  ]

  @spec snapshot() :: map()
  def snapshot do
    transport_plan = LocalFetchTransportValidationPlan.snapshot()

    %{
      manifest_version: 1,
      boundary: :local_full_message_resolution_evidence_manifest,
      current_mode: :beacon_refs_unresolved_without_real_transport,
      beacon_ref_contract_present?: true,
      resolver_contract_present?: true,
      fetch_request_contract_present?: true,
      fetch_planning_pipeline_present?: true,
      fake_offline_fetch_present?: true,
      real_fetch_transport_validated?: false,
      gatt_fetch_enabled_by_default?: transport_plan.gatt_fetch_enabled_by_default?,
      full_message_resolution_claim_allowed?: false,
      message_delivery_claim_allowed?: false,
      trusted_message_claim_allowed?: false,
      transport_validation_plan: transport_plan,
      contract_coverage: contract_coverage(),
      required_commands: @required_commands,
      required_artifacts: required_artifacts(),
      blocked_claims: blocked_claims(),
      satisfied_transport_gate_count: transport_plan.satisfied_gate_count,
      blocked_transport_gate_count: transport_plan.blocked_gate_count,
      open_transport_evidence: missing_transport_evidence(transport_plan),
      transport_evidence_review: LocalFullMessageResolutionEvidenceReview.review(%{}),
      known_good_transport_review: LocalKnownGoodTransportEvidenceReview.review(%{}),
      notes: [
        "Beacon refs remain pointers until a real transport retrieves and replay-parses the matching full MessageEnvelope.",
        "Fake/offline fetch proves contracts only; it is not hardware transport proof.",
        "The current SM-T577U/SM-T390 GATT path remains blocked before service discovery."
      ]
    }
  end

  @spec json_snapshot() :: map()
  def json_snapshot do
    snapshot()
    |> JSON.encode!()
    |> JSON.decode!()
  end

  defp contract_coverage do
    %{
      beacon_ref: %{
        module: "BeaconRef",
        status: :present,
        evidence: [
          "Parses canonical received_message_beacon into compact message reference fields.",
          "Matches a full MessageEnvelope by envelope_version, payload_kind, message_id_hash, and sender_peer_hash."
        ],
        tests: ["beacon_resolver_test.exs", "beacon_fetch_request_test.exs"]
      },
      resolver: %{
        module: "BeaconResolver",
        status: :present,
        outcomes: [:already_known, :needs_fetch, :unresolvable],
        tests: ["beacon_resolver_test.exs"]
      },
      fetch_request: %{
        module: "BeaconFetchRequest",
        status: :present,
        evidence: [
          "Builds deterministic, bounded fetch intents from {:needs_fetch, request}.",
          "Allows explicit empty candidate lists while preserving expiry validation."
        ],
        tests: ["beacon_fetch_request_test.exs"]
      },
      planning_pipeline: %{
        modules: [
          "BeaconFetchPlanner",
          "BeaconFetchAttemptLedger",
          "BeaconFetchDispatcher.DryRun"
        ],
        status: :present,
        evidence: [
          "Selects candidates deterministically.",
          "Records immutable planned attempts.",
          "Produces dry-run outcomes without dispatching transport."
        ],
        tests: ["beacon_fetch_pipeline_test.exs"]
      },
      offline_fetch: %{
        modules: [
          "BeaconFetchProtocol",
          "EnvelopeCache",
          "BeaconFetchTransport.Fake"
        ],
        status: :present,
        evidence: [
          "Defines canonical in-memory request/response messages.",
          "Caches canonical MessageEnvelope values by message_id_hash.",
          "Simulates requester/responder fetch exchange without transport."
        ],
        tests: ["beacon_fetch_transport_test.exs"]
      }
    }
  end

  defp required_artifacts do
    [
      %{
        id: :full_message_resolution_evidence_manifest,
        command: "mix mob.node.local_full_resolution.evidence --json --out <path>",
        purpose:
          "Archive beacon resolution contracts, offline fetch evidence, and blocked real transport gates."
      },
      %{
        id: :full_resolution_transport_evidence_template,
        command: "mix mob.node.local_full_resolution.transport_review --template --out <path>",
        purpose:
          "Generate incomplete operator metadata scaffold for full-message-resolution transport evidence."
      },
      %{
        id: :known_good_transport_evidence_template,
        command: "mix mob.node.local_known_good_transport.review --template --out <path>",
        purpose:
          "Generate incomplete operator metadata scaffold for known-good constrained fetch transport evidence."
      },
      %{
        id: :known_good_transport_logs,
        command:
          "mix mob.node.local_known_good_transport.review --input <path> --json --out <path>",
        purpose:
          "Review known-good transport selection and standalone interop metadata before any transport wording changes."
      },
      %{
        id: :canonical_resolution_replay_fixture,
        status: :operator_supplied_open,
        path: "artifacts/local-ble/<run-id>/full-resolution/replay/",
        purpose:
          "Attach replay-normalized hardware fetch fixture proving the retrieved envelope matches the original beacon ref."
      },
      %{
        id: :full_resolution_release_review,
        command:
          "mix mob.node.local_full_resolution.transport_review --input <path> --json --out <path>",
        purpose:
          "Review operator-supplied transport metadata before any real beacon resolution wording changes."
      }
    ]
  end

  defp missing_transport_evidence(transport_plan) do
    transport_plan.gates
    |> Enum.filter(&(&1.status == :blocked))
    |> Enum.map(fn gate ->
      %{
        gate_id: gate.id,
        required_evidence: gate.required_evidence,
        missing_evidence: gate.missing_evidence,
        blocked_claims: gate.blocked_claims
      }
    end)
  end

  defp blocked_claims do
    [
      :full_message_resolution,
      :known_good_transport,
      :gatt_fetch_success,
      :message_delivery,
      :trusted_message,
      :trusted_delivery,
      :routed_delivery,
      :background_delivery,
      :whole_project_complete
    ]
  end
end
