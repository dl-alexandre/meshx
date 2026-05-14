defmodule MeshxMobileApp.BLE.LocalLifecycleHardwareValidationPlan do
  @moduledoc """
  Hardware validation plan for mobile BLE lifecycle claims.

  The current validated mode is foreground/manual. This module records the
  device evidence required before MeshX can claim Android foreground service,
  Android/iOS background BLE, restart, scheduled retry, or background gossip
  behavior. It is validation planning data only: it does not start services,
  request background modes, schedule retries, scan, advertise, gossip, route,
  persist, ACK, retry, fetch, encrypt, or run background work.
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
        :target_device_matrix,
        [
          "Device model, OS/API version, BLE adapter state, battery policy, and app build id for every lifecycle run.",
          "Separate entries for foreground-only control runs and any background lifecycle candidate runs."
        ],
        [
          "Android target matrix for foreground service and background BLE validation.",
          "iOS target matrix if iOS background participation is required."
        ],
        [:background_operation, :ios_parity],
        [
          "Lifecycle evidence is device-specific and cannot be inferred from replay fixtures alone."
        ]
      ),
      gate(
        :android_foreground_service_backgrounding,
        [
          "Android logcat proving service start, notification visibility, scan/advertise state, app backgrounding, foreground return, stop, and close.",
          "Failure log proving service denial or permission failure remains operator-visible."
        ],
        [
          "Foreground-service implementation logs across app backgrounding.",
          "Operator-visible failure surface for missing permission, notification, or service start denial."
        ],
        [:android_foreground_service_ble, :background_delivery],
        ["Foreground service evidence must not claim delivery, routing, ACKs, or retries."]
      ),
      gate(
        :android_background_ble_policy,
        [
          "Policy fixture for allowed and blocked Android background scan/advertise behavior.",
          "Hardware logs showing OS throttling, permission, notification, and battery behavior."
        ],
        [
          "Android background scan/advertise policy.",
          "Hardware logs proving actual behavior under background and idle conditions."
        ],
        [:android_background_scan, :android_background_advertise],
        ["Background BLE policy must remain bounded by OS and battery constraints."]
      ),
      gate(
        :ios_background_ble_policy,
        [
          "Core Bluetooth capability and entitlement evidence if iOS background BLE is required.",
          "Replay-normalized hardware capture from an iOS background scan or advertise run."
        ],
        [
          "iOS background capability selection and bridge implementation evidence.",
          "iOS hardware logs proving actual background BLE behavior."
        ],
        [:ios_background_scan, :ios_background_advertise, :ios_parity],
        ["The iOS bridge shell is not background BLE proof."]
      ),
      gate(
        :restart_and_cancellation,
        [
          "Restart trigger policy with explicit cancellation and operator-visible status.",
          "Logs proving restart does not continue after explicit stop or denied permission."
        ],
        [
          "Automatic restart policy and implementation evidence.",
          "Cancellation and denied-permission logs."
        ],
        [:automatic_ble_restart, :operator_invisible_restart],
        ["Restart must be observable and cancellable before it can become product behavior."]
      ),
      gate(
        :scheduled_retry_bounds,
        [
          "Retry trigger policy, backoff bounds, maximum attempts, and cancellation behavior.",
          "Negative evidence proving scheduled retry does not imply guaranteed delivery."
        ],
        [
          "Scheduled retry bounds and cancellation fixtures.",
          "Failure-surface evidence for skipped, cancelled, and exhausted retry runs."
        ],
        [:scheduled_retry, :retry_backed_delivery, :background_delivery],
        ["Retry semantics remain blocked until product requirements and evidence exist."]
      ),
      gate(
        :background_gossip_limits,
        [
          "Rate limits, TTL/loop policy, battery budget, and platform constraint evidence.",
          "Hardware logs proving background gossip without routing, ACK, retry, or delivery claims."
        ],
        [
          "Background gossip rate-limit policy.",
          "Multi-device hardware logs for bounded background propagation if required."
        ],
        [:background_gossip, :background_forwarding, :background_delivery],
        ["Foreground one-hop gossip proof cannot be promoted into background gossip evidence."]
      ),
      gate(
        :negative_claim_review,
        [
          "Implementation-backed negative fixtures for foreground-only runs, OS throttling, restart cancellation, scheduled retry blocking, and background gossip bounds.",
          "Release-note review that background wording remains blocked until every relevant gate passes."
        ],
        [
          "Negative lifecycle fixture matrix tied to real implementation behavior.",
          "Operator release-note review preserving blocked claims."
        ],
        [:background_operation, :guaranteed_delivery, :routed_delivery],
        [
          "Negative evidence must move from pure claim gates to implementation-backed fixtures before release."
        ]
      )
    ]
  end

  @spec snapshot() :: map()
  def snapshot do
    gates = gates()

    %{
      plan_version: 1,
      boundary: :mobile_ble_lifecycle_hardware_validation_plan,
      current_validated_mode: :foreground_manual,
      background_claims_allowed?: false,
      restart_claims_allowed?: false,
      scheduled_retry_claims_allowed?: false,
      background_gossip_claims_allowed?: false,
      gate_count: length(gates),
      blocked_gate_count: Enum.count(gates, &(&1.status == :blocked)),
      gates: gates,
      blocked_claims: [
        :android_foreground_service_ble,
        :android_background_scan,
        :android_background_advertise,
        :ios_background_scan,
        :ios_background_advertise,
        :automatic_ble_restart,
        :scheduled_retry,
        :background_gossip,
        :background_delivery
      ],
      notes: [
        "Foreground/manual BLE remains the only validated lifecycle mode.",
        "Lifecycle validation must be device-specific because OS policy controls background BLE behavior.",
        "This plan adds evidence gates only; it does not change Android or iOS lifecycle behavior."
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
