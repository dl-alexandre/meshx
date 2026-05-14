defmodule MeshxMobileApp.BLE.LocalSecurityTrustLifecyclePlan do
  @moduledoc """
  Pure lifecycle plan for future persistent local security trust.

  The current local security path accepts supplied key material, supplied
  operator trust policy, and bounded in-memory replay state. This module
  records the remaining lifecycle gates before those supplied inputs can
  become a durable product trust lifecycle. It does not persist keys, persist
  trust, rotate keys, revoke keys, verify signatures, fetch, route, ACK,
  retry, encrypt, or run background work.
  """

  defmodule Gate do
    @moduledoc false

    @derive {JSON.Encoder,
             only: [
               :id,
               :status,
               :required_artifacts,
               :validation_evidence,
               :blocked_claims,
               :notes
             ]}
    @enforce_keys [
      :id,
      :status,
      :required_artifacts,
      :validation_evidence,
      :blocked_claims,
      :notes
    ]
    defstruct @enforce_keys
  end

  @blocked_claims [
    :persistent_trust_store,
    :automatic_key_discovery,
    :key_rotation,
    :revocation_sync,
    :trusted_delivery
  ]

  @gates [
    %{
      id: :key_enrollment,
      status: :planned,
      required_artifacts: [
        "Operator-visible enrollment action for peer_id and Ed25519 key_id.",
        "Canonical audit record for the enrollment source and reason.",
        "Negative fixture proving passive peer labels cannot enroll themselves."
      ],
      validation_evidence: [
        "Enrollment fixture creates a LocalSecurityOperatorTrustPolicy entry only from explicit operator input.",
        "Replay fixture proves unknown peer/key remains untrusted until enrollment evidence exists."
      ],
      blocked_claims: [:automatic_key_discovery, :trusted_message],
      notes: [
        "M421-M425 provides supplied policy entries only; it is not enrollment UX or storage."
      ]
    },
    %{
      id: :persistent_key_store,
      status: :planned,
      required_artifacts: [
        "Encrypted or platform-protected key/trust store policy.",
        "Migration and schema versioning for peer_id/key_id trust entries.",
        "Backup/restore and clear-all semantics."
      ],
      validation_evidence: [
        "Store round-trip fixture for trusted, untrusted, blocked, and revoked entries.",
        "Corruption and unsupported-version fixtures fail closed.",
        "Clear-all fixture removes durable trust state without touching local inbox observations."
      ],
      blocked_claims: [:persistent_trust_store, :trusted_message],
      notes: ["The current LocalSecurityOperatorTrustPolicy is in-memory supplied evidence."]
    },
    %{
      id: :key_rotation,
      status: :planned,
      required_artifacts: [
        "Policy for adding a successor key without transferring trust implicitly.",
        "Audit record linking old key_id, new key_id, operator action, and reason.",
        "Negative fixture proving same peer_id with a new key_id starts unknown unless explicitly trusted."
      ],
      validation_evidence: [
        "Rotation fixture keeps old and new key ids distinct.",
        "Replay fixture proves old-key signatures do not validate against new-key trust entries."
      ],
      blocked_claims: [:key_rotation, :trusted_message],
      notes: ["M421-M425 already prevents trust from transferring across key_id mismatch."]
    },
    %{
      id: :revocation_lifecycle,
      status: :planned,
      required_artifacts: [
        "Operator-visible block/revoke action.",
        "Audit record for revocation source, reason, and timestamp.",
        "Policy for whether revoked keys can be re-enrolled."
      ],
      validation_evidence: [
        "Revoked policy fixture blocks otherwise valid canonical replay decisions.",
        "Post-revocation replay fixture proves future signed messages remain untrusted.",
        "Audit export fixture preserves revocation reason and key_id."
      ],
      blocked_claims: [:revocation_sync, :trusted_message],
      notes: ["Current revocation is a supplied policy state, not durable lifecycle behavior."]
    },
    %{
      id: :replay_state_lifecycle,
      status: :planned,
      required_artifacts: [
        "Policy deciding whether replay state is memory-only or durable.",
        "Bounded retention and pruning rules.",
        "Clock-skew and restart behavior."
      ],
      validation_evidence: [
        "Duplicate signed proof fixture remains blocked within the configured replay window.",
        "Restart fixture documents whether replay cache survives app restart.",
        "Pruning fixture proves bounded memory or storage behavior."
      ],
      blocked_claims: [:fresh_message, :trusted_delivery],
      notes: ["Current replay protection is bounded and in-memory only."]
    },
    %{
      id: :release_audit_export,
      status: :planned,
      required_artifacts: [
        "Release-candidate trust lifecycle manifest.",
        "Operator-readable blocked-claim wording for trust lifecycle limitations.",
        "Evidence bundle links for enrollment, rotation, revocation, and replay fixtures."
      ],
      validation_evidence: [
        "Manifest fixture lists every open lifecycle gate.",
        "Release wording fixture blocks trusted-delivery claims without transport proof."
      ],
      blocked_claims: [:trusted_delivery, :whole_project_complete],
      notes: [
        "Trust lifecycle evidence is not full-message resolution, routing, or delivery evidence."
      ]
    }
  ]

  @spec gates() :: [Gate.t()]
  def gates, do: Enum.map(@gates, &struct!(Gate, &1))

  @spec get(atom()) :: {:ok, Gate.t()} | {:error, :not_found}
  def get(id) do
    case Enum.find(gates(), &(&1.id == id)) do
      %Gate{} = gate -> {:ok, gate}
      nil -> {:error, :not_found}
    end
  end

  @spec snapshot() :: map()
  def snapshot do
    gates = gates()
    validation = MeshxMobileApp.BLE.LocalSecurityTrustLifecycleValidation.snapshot()
    replay_lifecycle = MeshxMobileApp.BLE.LocalSecurityReplayLifecycleValidation.snapshot()

    %{
      plan_version: 1,
      boundary: :future_persistent_local_security_trust_lifecycle,
      gates: gates,
      validation: validation,
      replay_lifecycle: replay_lifecycle,
      open_gate_count: length(gates),
      validation_case_count: validation.case_count,
      validation_passed_count: validation.passed_count,
      replay_lifecycle_case_count: replay_lifecycle.case_count,
      replay_lifecycle_passed_count: replay_lifecycle.passed_count,
      blocked_claims: @blocked_claims,
      persistent_trust_store_complete?: false,
      key_rotation_complete?: false,
      revocation_lifecycle_complete?: false,
      trusted_delivery_claim_allowed?: false,
      notes: [
        "Current security trust evidence is supplied and in-memory.",
        "Persistent trust lifecycle must fail closed for unknown, mismatched, blocked, and revoked peer/key states.",
        "Trust lifecycle evidence never proves message delivery."
      ]
    }
  end

  @spec json_snapshot() :: map()
  def json_snapshot do
    snapshot()
    |> JSON.encode!()
    |> JSON.decode!()
  end
end
