defmodule Mob.Node.BLE.LocalIOSParityOperatorCapturePlan do
  @moduledoc """
  Operator capture plan for iOS advert-only hardware parity evidence.

  The plan turns `LocalIOSParityHardwareEvidenceReview` gates into concrete
  artifact slots that can be filled before iOS participation wording is
  considered. It does not change native iOS code, scan, advertise, fetch,
  route, persist, ACK, retry, encrypt, authenticate, or run background work.
  """

  alias Mob.Node.BLE.{
    LocalIOSParityHardwareEvidenceReview,
    LocalIOSParityHardwareValidationPlan
  }

  @spec snapshot() :: map()
  def snapshot do
    review = LocalIOSParityHardwareEvidenceReview

    %{
      plan_version: 1,
      boundary: :local_ios_parity_operator_capture_plan,
      status: :open,
      current_ios_mode: :contract_only,
      ios_hardware_evidence_complete?: false,
      ios_participation_claim_allowed?: false,
      ios_hardware_claim_allowed?: false,
      ios_legacy_beacon_observe_claim_allowed?: false,
      ios_legacy_beacon_gossip_claim_allowed?: false,
      ios_full_envelope_advert_claim_allowed?: false,
      ios_background_ble_claim_allowed?: false,
      ios_parity_claim_allowed?: false,
      hardware_validation_plan: LocalIOSParityHardwareValidationPlan.snapshot(),
      required_gates: review.required_gates(),
      required_evidence_types: review.required_evidence_types(),
      required_blocked_claims: review.required_blocked_claims(),
      required_gate_blocked_claims: review.required_gate_blocked_claims(),
      capture_sections: capture_sections(review),
      review_commands: review_commands(),
      artifact_root: "artifacts/local-ble/<run-id>/ios/",
      notes: [
        "This plan is an operator capture checklist, not evidence by itself.",
        "iOS has partial foreground observe/responder-fetch evidence; broader parity still requires selected behavior to be captured on hardware and replay-normalized.",
        "Android hardware evidence cannot satisfy iOS parity gates.",
        "iOS gossip, direct full-envelope advert, background BLE, and parity claims remain blocked."
      ]
    }
  end

  @spec json_snapshot() :: map()
  def json_snapshot do
    snapshot()
    |> JSON.encode!()
    |> JSON.decode!()
  end

  defp capture_sections(review) do
    gate_claims = review.required_gate_blocked_claims()

    Enum.map(review.required_gates(), fn gate_id ->
      section(
        review,
        gate_claims,
        gate_id,
        artifact_path(gate_id),
        notes(gate_id)
      )
    end)
  end

  defp section(review, gate_claims, gate_id, artifact_path, notes) do
    %{
      id: gate_id,
      review_section: gate_id,
      artifact_path: artifact_path,
      evidence_type: Map.fetch!(review.required_evidence_types(), gate_id),
      required_entries: [
        :artifact_path,
        :summary,
        :test_command,
        :evidence_type,
        :blocked_claims_called_out
      ],
      blocked_claims_called_out: review.required_blocked_claims(),
      gate_specific_blocked_claims_called_out: Map.get(gate_claims, gate_id, []),
      notes: notes
    }
  end

  defp artifact_path(:target_ios_device_matrix),
    do: "artifacts/local-ble/<run-id>/ios/target-devices.json"

  defp artifact_path(:canonical_ingress_fixture),
    do: "artifacts/local-ble/<run-id>/ios/canonical-ingress.jsonl"

  defp artifact_path(:legacy_beacon_observe_hardware),
    do: "artifacts/local-ble/<run-id>/ios/legacy-beacon-observe/"

  defp artifact_path(:legacy_beacon_gossip_hardware),
    do: "artifacts/local-ble/<run-id>/ios/legacy-beacon-gossip/"

  defp artifact_path(:full_envelope_capability_probe),
    do: "artifacts/local-ble/<run-id>/ios/full-envelope-capability.md"

  defp artifact_path(:hardware_replay_fixture),
    do: "artifacts/local-ble/<run-id>/ios/replay/"

  defp artifact_path(:ios_background_ble_boundary),
    do: "artifacts/local-ble/<run-id>/ios/background-boundary.md"

  defp artifact_path(:negative_claim_review),
    do: "artifacts/local-ble/<run-id>/ios/negative-claims.md"

  defp notes(:target_ios_device_matrix) do
    [
      "Attach iPhone/iPad model, iOS version, BLE state, permission state, app build, run role, and observer metadata for every iOS claim."
    ]
  end

  defp notes(:canonical_ingress_fixture) do
    [
      "Attach iOS-origin canonical received_message_beacon or received_message fixtures that replay through shared ingress."
    ]
  end

  defp notes(:legacy_beacon_observe_hardware) do
    [
      "Attach iOS hardware logs proving legacy beacon observation; observed beacons remain pointer/ref evidence, not delivery."
    ]
  end

  defp notes(:legacy_beacon_gossip_hardware) do
    [
      "Attach iOS-origin legacy beacon emission or gossip logs plus a second MeshX observer capture without routing, ACK, retry, or delivery claims."
    ]
  end

  defp notes(:full_envelope_capability_probe) do
    [
      "Attach iOS payload budget and scan compatibility evidence or an explicit negative capability ledger."
    ]
  end

  defp notes(:hardware_replay_fixture) do
    [
      "Attach replay-normalized iOS hardware fixtures with raw capture references and device metadata."
    ]
  end

  defp notes(:ios_background_ble_boundary) do
    [
      "Attach explicit foreground-only or background-capable policy; background BLE requires separate Core Bluetooth capability and hardware evidence."
    ]
  end

  defp notes(:negative_claim_review) do
    [
      "Attach implementation-backed negative fixtures proving bridge shell, Android evidence, missing dispatcher, unproven capability, and missing replay fixture cannot satisfy iOS parity."
    ]
  end

  defp review_commands do
    [
      "mix mob.node.local_ios_parity.hardware_review --template --out artifacts/local-ble/<run-id>/ios/evidence.json",
      "mix mob.node.local_ios_parity.hardware_review --input artifacts/local-ble/<run-id>/ios/evidence.json --json --out tmp/local-ios-parity-hardware-review.json"
    ]
  end
end
