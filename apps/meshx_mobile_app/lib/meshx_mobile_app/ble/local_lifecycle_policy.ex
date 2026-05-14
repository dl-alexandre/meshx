defmodule MeshxMobileApp.BLE.LocalLifecyclePolicy do
  @moduledoc """
  Claim policy for the current mobile BLE lifecycle mode.

  MeshX mobile BLE is currently validated as foreground/manual behavior.
  This policy records which lifecycle claims are allowed and which are
  blocked until platform services and hardware evidence exist.

  It does not start services, request background modes, schedule work,
  scan, advertise, route, persist, ACK, retry, encrypt, fetch, or run in
  the background.
  """

  defmodule Capability do
    @moduledoc false

    @enforce_keys [:id, :status, :allowed_claims, :blocked_claims, :required_before_allowed]
    defstruct @enforce_keys

    @type id ::
            :foreground_manual_operation
            | :android_foreground_service
            | :android_background_ble
            | :ios_background_ble
            | :automatic_restart
            | :scheduled_retry
            | :background_gossip

    @type status :: :allowed | :blocked

    @type t :: %__MODULE__{
            id: id(),
            status: status(),
            allowed_claims: [binary()],
            blocked_claims: [binary()],
            required_before_allowed: [atom()]
          }
  end

  @capabilities [
    %{
      id: :foreground_manual_operation,
      status: :allowed,
      allowed_claims: [
        "Foreground scan and advertise operations started and stopped explicitly by the app or validation harness."
      ],
      blocked_claims: [
        "Automatic background continuation.",
        "OS-managed restart.",
        "Scheduled retry or background gossip."
      ],
      required_before_allowed: []
    },
    %{
      id: :android_foreground_service,
      status: :blocked,
      allowed_claims: [],
      blocked_claims: [
        "Android foreground-service BLE operation.",
        "BLE behavior across Android app backgrounding."
      ],
      required_before_allowed: [
        :android_service_manifest,
        :notification_policy,
        :hardware_backgrounding_evidence
      ]
    },
    %{
      id: :android_background_ble,
      status: :blocked,
      allowed_claims: [],
      blocked_claims: [
        "Android background scan.",
        "Android background advertise.",
        "Android OS-throttling safe behavior."
      ],
      required_before_allowed: [:android_background_policy, :battery_bounds, :hardware_logs]
    },
    %{
      id: :ios_background_ble,
      status: :blocked,
      allowed_claims: [],
      blocked_claims: [
        "iOS background scan.",
        "iOS background advertise.",
        "iOS replay-normalized background observations."
      ],
      required_before_allowed: [:ios_capabilities, :core_bluetooth_policy, :ios_hardware_logs]
    },
    %{
      id: :automatic_restart,
      status: :blocked,
      allowed_claims: [],
      blocked_claims: [
        "Automatic BLE restart after app/process interruption.",
        "Operator-invisible restart behavior."
      ],
      required_before_allowed: [:restart_policy, :cancellation_policy, :operator_status]
    },
    %{
      id: :scheduled_retry,
      status: :blocked,
      allowed_claims: [],
      blocked_claims: [
        "Scheduled scan/advertise retry.",
        "Retry-backed delivery or fetch semantics."
      ],
      required_before_allowed: [:retry_policy, :backoff_policy, :failure_surface]
    },
    %{
      id: :background_gossip,
      status: :blocked,
      allowed_claims: [],
      blocked_claims: [
        "Background advert gossip.",
        "Background forwarding.",
        "Background delivery behavior."
      ],
      required_before_allowed: [:rate_limits, :ttl_policy, :battery_bounds, :hardware_validation]
    }
  ]

  @spec capabilities() :: [Capability.t()]
  def capabilities, do: Enum.map(@capabilities, &struct!(Capability, &1))

  @spec get(Capability.id()) :: {:ok, Capability.t()} | {:error, :not_found}
  def get(id) do
    case Enum.find(capabilities(), &(&1.id == id)) do
      %Capability{} = capability -> {:ok, capability}
      nil -> {:error, :not_found}
    end
  end

  @spec allowed() :: [Capability.t()]
  def allowed, do: Enum.filter(capabilities(), &(&1.status == :allowed))

  @spec blocked() :: [Capability.t()]
  def blocked, do: Enum.filter(capabilities(), &(&1.status == :blocked))

  @spec snapshot() :: map()
  def snapshot do
    %{
      mode: :foreground_manual_ble,
      decision_outcome: :keep_foreground_manual,
      decision_status: :selected_for_current_validated_mode,
      background_lifecycle_reconsideration_gate: :mobile_ble_lifecycle_hardware_validation_plan,
      capabilities: capabilities(),
      allowed_count: length(allowed()),
      blocked_count: length(blocked()),
      background_claims_allowed?: false,
      foreground_service_claim_allowed?: false,
      restart_claims_allowed?: false,
      scheduled_retry_claim_allowed?: false,
      background_gossip_claim_allowed?: false,
      notes: [
        "Foreground/manual BLE operation is the only lifecycle claim currently allowed.",
        "Android foreground service and iOS background BLE behavior are not implemented or validated.",
        "No automatic restart, scheduled retry, or background gossip is claimed."
      ]
    }
  end
end
