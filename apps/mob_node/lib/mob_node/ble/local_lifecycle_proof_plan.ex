defmodule Mob.Node.BLE.LocalLifecycleProofPlan do
  @moduledoc """
  Proof plan for future mobile BLE lifecycle claims.

  The current validated mobile BLE mode is foreground/manual. This module
  maps each open background lifecycle requirement to future implementation
  gates and validation evidence before MeshX may claim foreground services,
  background BLE, restart, scheduled retry, or background gossip. It does not
  start services, request OS background modes, schedule work, scan, advertise,
  route, persist, ACK, retry, fetch, encrypt, or run background work.
  """

  alias Mob.Node.BLE.LocalBackgroundLifecycleContract

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
            requirement_id: LocalBackgroundLifecycleContract.Requirement.id(),
            status: :planned | :platform_blocked,
            implementation_gates: [atom()],
            validation_evidence: [binary()],
            blocked_claims: [atom()],
            notes: [binary()]
          }
  end

  @proof_gates %{
    android_foreground_service: %{
      status: :planned,
      implementation_gates: [
        :android_manifest_service_declaration,
        :foreground_service_permission,
        :notification_policy,
        :bounded_service_lifecycle,
        :explicit_stop_and_close
      ],
      validation_evidence: [
        "Android source and manifest evidence for a bounded foreground service.",
        "Hardware logs proving scan/advertise behavior across app backgrounding.",
        "Negative test proving foreground service does not imply delivery, routing, ACKs, or retries."
      ],
      blocked_claims: [:android_foreground_service_ble, :background_ble_operation],
      notes: [
        "Foreground service is optional and must be product-required before implementation."
      ]
    },
    android_background_ble_policy: %{
      status: :planned,
      implementation_gates: [
        :background_scan_policy,
        :background_advertise_policy,
        :permission_and_notification_policy,
        :battery_and_throttling_bounds,
        :operator_visible_status
      ],
      validation_evidence: [
        "Policy fixture describing allowed and blocked background scan/advertise actions.",
        "Hardware logs showing OS throttling and permission behavior.",
        "Battery and notification behavior documented for supported Android versions."
      ],
      blocked_claims: [:android_background_scan, :android_background_advertise],
      notes: ["Current Android validation remains foreground/manual."]
    },
    ios_background_ble_policy: %{
      status: :platform_blocked,
      implementation_gates: [
        :ios_background_capability_selection,
        :core_bluetooth_background_policy,
        :ios_bridge_background_events,
        :replay_normalized_hardware_capture,
        :battery_and_os_constraint_notes
      ],
      validation_evidence: [
        "iOS capability and entitlement evidence if background BLE is required.",
        "Hardware capture proving actual iOS background scan/advertise behavior.",
        "Replay-normalized fixture preserving canonical event shape."
      ],
      blocked_claims: [:ios_background_scan, :ios_background_advertise, :ios_parity_background],
      notes: ["iOS bridge shell does not imply background BLE support."]
    },
    automatic_restart: %{
      status: :planned,
      implementation_gates: [
        :restart_trigger_policy,
        :cancellation_policy,
        :backoff_without_delivery_claims,
        :operator_visible_restart_status,
        :failure_surface
      ],
      validation_evidence: [
        "Fixture proving restart trigger and cancellation behavior.",
        "Negative test proving restart does not imply retry-backed delivery.",
        "Status surface test proving restart is operator-visible."
      ],
      blocked_claims: [:automatic_ble_restart, :operator_invisible_restart],
      notes: ["Manual start/stop remains the only supported lifecycle today."]
    },
    background_gossip_limits: %{
      status: :planned,
      implementation_gates: [
        :background_gossip_rate_limits,
        :ttl_and_loop_policy,
        :battery_budget,
        :platform_background_constraints,
        :hardware_validation_without_delivery_claims
      ],
      validation_evidence: [
        "Policy fixture proving rate limits, TTL, and loop suppression remain bounded.",
        "Hardware logs proving background gossip behavior without fake delivery claims.",
        "Negative test proving background gossip does not imply routing, ACKs, or retries."
      ],
      blocked_claims: [:background_gossip, :background_forwarding, :background_delivery],
      notes: ["Background gossip is outside the current validated advert-only local mode."]
    }
  }

  @spec gates() :: [Gate.t()]
  def gates do
    LocalBackgroundLifecycleContract.open_requirements()
    |> Enum.map(&gate/1)
  end

  @spec get(LocalBackgroundLifecycleContract.Requirement.id()) ::
          {:ok, Gate.t()} | {:error, :not_found}
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
      proof_boundary: :future_mobile_ble_lifecycle,
      gates: gates,
      open_gate_count: length(gates),
      platform_blocked_count: Enum.count(gates, &(&1.status == :platform_blocked)),
      background_claims_allowed?: false,
      restart_claims_allowed?: false,
      notes: [
        "Every background lifecycle gate is planned or platform-blocked, not implemented.",
        "Foreground/manual BLE remains the only validated lifecycle mode.",
        "Background, restart, scheduled retry, and background gossip claims stay blocked until implementation and hardware evidence exist."
      ]
    }
  end

  @spec json_snapshot() :: map()
  def json_snapshot do
    snapshot()
    |> JSON.encode!()
    |> JSON.decode!()
  end

  defp gate(%LocalBackgroundLifecycleContract.Requirement{id: id}) do
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
