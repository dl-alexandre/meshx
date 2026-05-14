defmodule MeshxMobileApp.BLE.LocalIOSParityAcceptance do
  @moduledoc """
  Acceptance boundary for iOS advert-only local mesh parity.

  Android has validated legacy beacon observe/gossip evidence. iOS currently
  has a bridge shell and shared canonical contracts only. This module records
  which iOS parity gates are contract-satisfied and which remain blocked by
  missing implementation, hardware capture, and replay-normalized fixtures.
  It does not touch native code, scan, advertise, fetch, route, persist, ACK,
  retry, encrypt, or run background work.
  """

  alias MeshxMobileApp.BLE.{
    LocalIOSParityContract,
    LocalIOSParityHardwareValidationPlan,
    LocalIOSParityNegativeValidation,
    LocalIOSParityPolicy,
    LocalIOSParityProofPlan
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
    :ios_hardware_participation,
    :ios_advert_only_validation,
    :ios_legacy_beacon_observed,
    :ios_legacy_beacon_gossip,
    :ios_full_envelope_advert,
    :ios_hardware_replay_fixture,
    :ios_background_ble,
    :ios_parity_claim
  ]

  @spec gates() :: [Gate.t()]
  def gates do
    policy = LocalIOSParityPolicy.snapshot()
    contract = LocalIOSParityContract.snapshot()
    proof_plan = LocalIOSParityProofPlan.snapshot()
    negative = LocalIOSParityNegativeValidation.snapshot()

    [
      shared_contract_gate(policy, contract),
      future_contract_gate(contract, proof_plan),
      hardware_validation_plan_gate(),
      negative_validation_gate(negative),
      canonical_ingress_gate(contract),
      legacy_beacon_observe_gate(contract),
      legacy_beacon_gossip_gate(contract),
      full_envelope_advert_gate(contract),
      hardware_replay_fixture_gate(contract),
      ios_background_ble_gate(policy)
    ]
  end

  @spec snapshot() :: map()
  def snapshot do
    gates = gates()

    %{
      acceptance_version: 1,
      boundary: :current_ios_contract_only_mode,
      gates: gates,
      satisfied_count: Enum.count(gates, &(&1.status == :satisfied)),
      blocked_count: Enum.count(gates, &(&1.status == :blocked)),
      ios_participation_claims_allowed?: false,
      ios_hardware_claims_allowed?: false,
      ios_parity_claims_allowed?: false,
      ios_background_claims_allowed?: false,
      blocked_claims: @blocked_claims,
      notes: [
        "iOS parity is contract-only until native advert-only behavior and hardware evidence exist.",
        "Android hardware evidence cannot satisfy iOS parity gates.",
        "Replay-normalized iOS hardware fixtures are required before any iOS advert-only participation claim."
      ]
    }
  end

  @spec json_snapshot() :: map()
  def json_snapshot do
    snapshot()
    |> JSON.encode!()
    |> JSON.decode!()
  end

  defp shared_contract_gate(policy, contract) do
    satisfied? =
      policy.contract_only_count == 1 and
        policy.ios_participation_claims_allowed? == false and
        contract.open_requirement_count == 5

    gate(
      :shared_canonical_contract,
      if(satisfied?, do: :satisfied, else: :blocked),
      [
        "Shared canonical received_message and received_message_beacon contracts exist for future iOS normalization."
      ],
      if(satisfied?, do: [], else: ["iOS shared canonical contract boundary is incomplete."]),
      [:ios_hardware_participation, :ios_advert_only_validation, :ios_parity_claim],
      ["Canonical contracts are necessary but not hardware proof."]
    )
  end

  defp future_contract_gate(contract, proof_plan) do
    complete? = contract.open_requirement_count == proof_plan.open_gate_count

    gate(
      :future_ios_parity_contract,
      if(complete?, do: :satisfied, else: :blocked),
      [
        "LocalIOSParityContract and LocalIOSParityProofPlan enumerate the same open iOS parity proof categories."
      ],
      if(complete?, do: [], else: ["iOS parity contract and proof plan gate counts diverge."]),
      @blocked_claims,
      ["The contract/proof plan is necessary evidence, not implementation."]
    )
  end

  defp hardware_validation_plan_gate do
    plan = LocalIOSParityHardwareValidationPlan.snapshot()

    required_gates = [
      :target_ios_device_matrix,
      :canonical_ingress_fixture,
      :legacy_beacon_observe_hardware,
      :legacy_beacon_gossip_hardware,
      :full_envelope_capability_probe,
      :hardware_replay_fixture,
      :ios_background_ble_boundary,
      :negative_claim_review
    ]

    present_gates = Enum.map(plan.gates, & &1.id)
    missing_gates = Enum.reject(required_gates, &(&1 in present_gates))

    satisfied? =
      missing_gates == [] and
        plan.ios_participation_claims_allowed? == false and
        plan.ios_hardware_claims_allowed? == false and
        plan.ios_parity_claims_allowed? == false

    gate(
      :ios_hardware_validation_plan,
      if(satisfied?, do: :satisfied, else: :blocked),
      [
        "LocalIOSParityHardwareValidationPlan records iOS device matrix, canonical ingress, legacy beacon observe/gossip, full-envelope capability, hardware replay, background boundary, and negative claim review gates."
      ],
      Enum.map(missing_gates, &"Missing iOS hardware validation gate #{inspect(&1)}."),
      @blocked_claims,
      [
        "The plan structures iOS hardware evidence without enabling iOS advert-only participation."
      ]
    )
  end

  defp negative_validation_gate(negative) do
    blocked? =
      negative.ios_participation_claims_allowed? == false and
        negative.ios_hardware_claims_allowed? == false and
        negative.ios_parity_claims_allowed? == false

    gate(
      :negative_ios_parity_validation,
      if(blocked?, do: :satisfied, else: :blocked),
      [
        "LocalIOSParityNegativeValidation blocks bridge-shell, Android-evidence, missing-dispatcher, unproven-capability, and missing-replay-fixture claims."
      ],
      if(blocked?, do: [], else: ["iOS negative validation allows a hardware or parity claim."]),
      negative.blocked_claims,
      [
        "Negative validation must be replaced by implementation-backed iOS positive and negative fixtures in future work."
      ]
    )
  end

  defp canonical_ingress_gate(contract), do: requirement_gate(contract, :canonical_ingress)

  defp legacy_beacon_observe_gate(contract),
    do: requirement_gate(contract, :legacy_beacon_observe)

  defp legacy_beacon_gossip_gate(contract), do: requirement_gate(contract, :legacy_beacon_gossip)
  defp full_envelope_advert_gate(contract), do: requirement_gate(contract, :full_envelope_advert)

  defp hardware_replay_fixture_gate(contract),
    do: requirement_gate(contract, :hardware_replay_fixture)

  defp ios_background_ble_gate(policy) do
    capability = Enum.find(policy.capabilities, &(&1.id == :ios_background_ble))

    gate(
      :ios_background_ble,
      :blocked,
      [],
      Enum.map(capability.required_before_allowed, &"Missing #{inspect(&1)}."),
      [:ios_background_ble, :ios_background_scan, :ios_background_advertise, :ios_parity_claim],
      ["iOS background BLE remains blocked separately from advert-only foreground parity."]
    )
  end

  defp requirement_gate(contract, id) do
    requirement = Enum.find(contract.requirements, &(&1.id == id))
    status = if(id == :canonical_ingress, do: :satisfied, else: :blocked)

    gate(
      id,
      status,
      if(status == :satisfied, do: ["Canonical ingress requirement is documented."], else: []),
      if(status == :satisfied,
        do: [],
        else: requirement.required_evidence ++ [requirement.current_gap]
      ),
      blocked_claims_for(id),
      requirement.notes
    )
  end

  defp blocked_claims_for(:canonical_ingress),
    do: [:ios_hardware_participation, :ios_parity_claim]

  defp blocked_claims_for(:legacy_beacon_observe),
    do: [:ios_legacy_beacon_observed, :ios_advert_only_validation, :ios_parity_claim]

  defp blocked_claims_for(:legacy_beacon_gossip),
    do: [:ios_legacy_beacon_gossip, :ios_parity_claim]

  defp blocked_claims_for(:full_envelope_advert),
    do: [:ios_full_envelope_advert, :ios_parity_claim]

  defp blocked_claims_for(:hardware_replay_fixture),
    do: [:ios_hardware_replay_fixture, :ios_advert_only_validation, :ios_parity_claim]

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
