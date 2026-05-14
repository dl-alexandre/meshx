defmodule MeshxMobileApp.BLE.LocalLifecycleAcceptance do
  @moduledoc """
  Acceptance boundary for mobile BLE lifecycle claims.

  The current validated lifecycle is foreground/manual operation. This module
  records which lifecycle gates are satisfied by that boundary and which
  future gates still block Android foreground-service, Android/iOS background
  BLE, automatic restart, scheduled retry, and background gossip claims. It
  does not start services, request background modes, schedule work, scan,
  advertise, route, persist, ACK, retry, fetch, encrypt, or run background
  work.
  """

  alias MeshxMobileApp.BLE.{
    LocalBackgroundLifecycleContract,
    LocalLifecycleHardwareValidationPlan,
    LocalLifecycleNegativeValidation,
    LocalLifecyclePolicy,
    LocalLifecycleProofPlan,
    LocalTransportLifecycleProfile
  }

  defmodule Gate do
    @moduledoc false

    @derive {JSON.Encoder,
             only: [
               :id,
               :status,
               :evidence,
               :missing,
               :blocked_claims,
               :notes
             ]}
    @enforce_keys [:id, :status, :evidence, :missing, :blocked_claims, :notes]
    defstruct @enforce_keys

    @type status :: :satisfied | :blocked

    @type t :: %__MODULE__{
            id: atom(),
            status: status(),
            evidence: [binary()],
            missing: [binary()],
            blocked_claims: [atom()],
            notes: [binary()]
          }
  end

  @blocked_claims [
    :android_foreground_service_ble,
    :android_background_scan,
    :android_background_advertise,
    :ios_background_scan,
    :ios_background_advertise,
    :automatic_ble_restart,
    :scheduled_retry,
    :background_gossip,
    :background_delivery
  ]

  @spec gates(LocalTransportLifecycleProfile.t()) :: [Gate.t()]
  def gates(profile \\ LocalTransportLifecycleProfile.foreground_manual()) do
    policy = LocalLifecyclePolicy.snapshot()
    profile_snapshot = LocalTransportLifecycleProfile.snapshot(profile)
    contract = LocalBackgroundLifecycleContract.snapshot()
    proof_plan = LocalLifecycleProofPlan.snapshot()
    negative = LocalLifecycleNegativeValidation.snapshot()

    [
      foreground_profile_gate(profile_snapshot),
      lifecycle_policy_gate(policy),
      future_contract_gate(contract, proof_plan),
      hardware_validation_plan_gate(),
      negative_validation_gate(negative),
      android_foreground_service_gate(contract),
      android_background_ble_gate(contract),
      ios_background_ble_gate(contract),
      automatic_restart_gate(contract),
      background_gossip_gate(contract),
      scheduled_retry_gate()
    ]
  end

  @spec snapshot(LocalTransportLifecycleProfile.t()) :: map()
  def snapshot(profile \\ LocalTransportLifecycleProfile.foreground_manual()) do
    gates = gates(profile)

    %{
      acceptance_version: 1,
      boundary: :current_foreground_manual_lifecycle,
      gates: gates,
      satisfied_count: Enum.count(gates, &(&1.status == :satisfied)),
      blocked_count: Enum.count(gates, &(&1.status == :blocked)),
      background_claims_allowed?: false,
      restart_claims_allowed?: false,
      scheduled_retry_claims_allowed?: false,
      background_gossip_claims_allowed?: false,
      blocked_claims: @blocked_claims,
      notes: [
        "Foreground/manual BLE is the only lifecycle mode accepted today.",
        "Foreground harness evidence does not prove app-backgrounding, restart, scheduled retry, or background gossip behavior.",
        "Background lifecycle claims remain blocked until platform implementation and hardware evidence exist."
      ]
    }
  end

  @spec json_snapshot(LocalTransportLifecycleProfile.t()) :: map()
  def json_snapshot(profile \\ LocalTransportLifecycleProfile.foreground_manual()) do
    profile
    |> snapshot()
    |> JSON.encode!()
    |> JSON.decode!()
  end

  defp foreground_profile_gate(profile) do
    supported? =
      :foreground_scan in profile.supports and
        :foreground_advertise in profile.supports and
        :explicit_start_stop in profile.supports

    unsupported? =
      :android_foreground_service in profile.does_not_support and
        :ios_background_scan in profile.does_not_support and
        :automatic_restart in profile.does_not_support

    gate(
      :foreground_manual_profile,
      if(supported? and unsupported?, do: :satisfied, else: :blocked),
      [
        "LocalTransportLifecycleProfile supports foreground scan/advertise and explicit start/stop while listing background/restart behavior as unsupported."
      ],
      if(supported? and unsupported?,
        do: [],
        else: ["Lifecycle profile no longer preserves the foreground/manual boundary."]
      ),
      @blocked_claims,
      ["The profile is capability data; it does not run BLE operations."]
    )
  end

  defp lifecycle_policy_gate(policy) do
    satisfied? =
      policy.allowed_count == 1 and
        policy.blocked_count == 6 and
        policy.background_claims_allowed? == false and
        policy.restart_claims_allowed? == false

    gate(
      :lifecycle_policy,
      if(satisfied?, do: :satisfied, else: :blocked),
      [
        "LocalLifecyclePolicy allows foreground/manual operation and blocks background, restart, scheduled retry, and background gossip claims."
      ],
      if(satisfied?,
        do: [],
        else: ["Lifecycle policy no longer blocks required background or restart claims."]
      ),
      @blocked_claims,
      ["Policy gates release wording; it does not implement platform lifecycle behavior."]
    )
  end

  defp future_contract_gate(contract, proof_plan) do
    complete? = contract.open_requirement_count == proof_plan.open_gate_count

    gate(
      :future_lifecycle_contract,
      if(complete?, do: :satisfied, else: :blocked),
      [
        "LocalBackgroundLifecycleContract and LocalLifecycleProofPlan enumerate the same open lifecycle proof categories."
      ],
      if(complete?, do: [], else: ["Lifecycle contract and proof plan gate counts diverge."]),
      @blocked_claims,
      ["The contract/proof plan is necessary evidence, not implementation."]
    )
  end

  defp hardware_validation_plan_gate do
    plan = LocalLifecycleHardwareValidationPlan.snapshot()

    required_gates = [
      :target_device_matrix,
      :android_foreground_service_backgrounding,
      :android_background_ble_policy,
      :ios_background_ble_policy,
      :restart_and_cancellation,
      :scheduled_retry_bounds,
      :background_gossip_limits,
      :negative_claim_review
    ]

    present_gates = Enum.map(plan.gates, & &1.id)
    missing_gates = Enum.reject(required_gates, &(&1 in present_gates))

    satisfied? =
      missing_gates == [] and
        plan.background_claims_allowed? == false and
        plan.restart_claims_allowed? == false and
        plan.scheduled_retry_claims_allowed? == false

    gate(
      :lifecycle_hardware_validation_plan,
      if(satisfied?, do: :satisfied, else: :blocked),
      [
        "LocalLifecycleHardwareValidationPlan records target device, foreground-service, Android/iOS background BLE, restart, scheduled retry, background gossip, and negative claim review evidence gates."
      ],
      Enum.map(missing_gates, &"Missing lifecycle hardware validation gate #{inspect(&1)}."),
      @blocked_claims,
      ["The plan structures hardware evidence without enabling background lifecycle behavior."]
    )
  end

  defp negative_validation_gate(negative) do
    blocked? =
      negative.background_claims_allowed? == false and
        negative.restart_claims_allowed? == false and
        negative.scheduled_retry_claims_allowed? == false

    gate(
      :negative_lifecycle_validation,
      if(blocked?, do: :satisfied, else: :blocked),
      [
        "LocalLifecycleNegativeValidation blocks foreground-as-background, Android/iOS background, automatic restart, fetch-intent-as-retry, and background gossip claims."
      ],
      if(blocked?,
        do: [],
        else: [
          "Lifecycle negative validation allows a background, restart, or scheduled retry claim."
        ]
      ),
      negative.blocked_claims,
      [
        "Negative validation must be replaced by implementation-backed positive and negative fixtures in future work."
      ]
    )
  end

  defp android_foreground_service_gate(contract),
    do: requirement_gate(contract, :android_foreground_service)

  defp android_background_ble_gate(contract),
    do: requirement_gate(contract, :android_background_ble_policy)

  defp ios_background_ble_gate(contract),
    do: requirement_gate(contract, :ios_background_ble_policy)

  defp automatic_restart_gate(contract), do: requirement_gate(contract, :automatic_restart)
  defp background_gossip_gate(contract), do: requirement_gate(contract, :background_gossip_limits)

  defp scheduled_retry_gate do
    gate(
      :scheduled_retry,
      :blocked,
      [],
      [
        "Retry trigger policy and backoff bounds.",
        "Cancellation and operator-visible status.",
        "Failure surface proving scheduled retry does not imply delivery.",
        "Implementation-backed tests or hardware logs if product requirements need scheduled retry."
      ],
      [:scheduled_retry, :retry_backed_delivery, :background_delivery],
      [
        "Scheduled retry is blocked separately because no open lifecycle contract allows it today."
      ]
    )
  end

  defp requirement_gate(contract, id) do
    requirement = Enum.find(contract.requirements, &(&1.id == id))

    gate(
      id,
      :blocked,
      [],
      requirement.required_evidence ++ [requirement.current_gap],
      blocked_claims_for(id),
      requirement.notes
    )
  end

  defp blocked_claims_for(:android_foreground_service),
    do: [:android_foreground_service_ble, :background_ble_operation]

  defp blocked_claims_for(:android_background_ble_policy),
    do: [:android_background_scan, :android_background_advertise]

  defp blocked_claims_for(:ios_background_ble_policy),
    do: [:ios_background_scan, :ios_background_advertise]

  defp blocked_claims_for(:automatic_restart),
    do: [:automatic_ble_restart, :scheduled_retry]

  defp blocked_claims_for(:background_gossip_limits),
    do: [:background_gossip, :background_delivery]

  defp gate(id, status, evidence, missing, blocked_claims, notes) do
    %Gate{
      id: id,
      status: status,
      evidence: evidence,
      missing: missing,
      blocked_claims: blocked_claims,
      notes: notes
    }
  end
end
