defmodule MeshxMobileApp.BLE.LocalLifecycleOperatorCapturePlan do
  @moduledoc """
  Operator capture plan for mobile BLE lifecycle evidence.

  The plan turns `LocalLifecycleHardwareValidationPlan` gates into concrete
  artifact slots that can be filled before running
  `LocalLifecycleHardwareEvidenceReview`. It does not start Android services,
  request iOS background modes, schedule retries, scan, advertise, gossip,
  route, persist, ACK, retry, fetch, encrypt, authenticate, or run background
  work.
  """

  alias MeshxMobileApp.BLE.{
    LocalLifecycleHardwareEvidenceReview,
    LocalLifecycleHardwareValidationPlan,
    LocalLifecyclePolicy
  }

  @spec snapshot() :: map()
  def snapshot do
    policy = LocalLifecyclePolicy.snapshot()
    review = LocalLifecycleHardwareEvidenceReview

    %{
      plan_version: 1,
      boundary: :local_lifecycle_operator_capture_plan,
      status: :open,
      current_lifecycle_decision: current_lifecycle_decision(policy),
      current_mode: :foreground_manual,
      android_foreground_service_claim_allowed?: false,
      android_background_ble_claim_allowed?: false,
      ios_background_claim_allowed?: false,
      background_ble_claim_allowed?: false,
      restart_claim_allowed?: false,
      scheduled_retry_claim_allowed?: false,
      background_gossip_claim_allowed?: false,
      delivery_claim_allowed?: false,
      hardware_validation_plan: LocalLifecycleHardwareValidationPlan.snapshot(),
      required_gates: review.required_gates(),
      required_evidence_types: review.required_evidence_types(),
      required_blocked_claims: review.required_blocked_claims(),
      required_gate_blocked_claims: review.required_gate_blocked_claims(),
      capture_sections: capture_sections(review),
      review_commands: review_commands(),
      artifact_root: "artifacts/local-ble/<run-id>/lifecycle/",
      notes: [
        "This plan is an operator capture checklist, not evidence by itself.",
        "The current selected decision is keep_foreground_manual.",
        "Foreground/manual harness evidence is not Android foreground-service or iOS background behavior.",
        "Foreground-service, background BLE, restart, scheduled retry, background gossip, and delivery claims remain blocked."
      ]
    }
  end

  @spec json_snapshot() :: map()
  def json_snapshot do
    snapshot()
    |> JSON.encode!()
    |> JSON.decode!()
  end

  defp current_lifecycle_decision(policy) do
    %{
      decision_outcome: policy.decision_outcome,
      decision_status: policy.decision_status,
      background_lifecycle_reconsideration_gate: policy.background_lifecycle_reconsideration_gate,
      android_foreground_service_enabled?: false,
      android_background_ble_enabled?: false,
      ios_background_ble_enabled?: false,
      automatic_restart_enabled?: false,
      scheduled_retry_enabled?: false,
      background_gossip_enabled?: false
    }
  end

  defp capture_sections(review) do
    gate_claims = review.required_gate_blocked_claims()

    [
      section(
        review,
        gate_claims,
        :target_device_matrix,
        "artifacts/local-ble/<run-id>/lifecycle/targets.json",
        [
          "Attach device model, OS/API version, BLE adapter state, battery policy, app build id, and foreground/background run role for every lifecycle target."
        ]
      ),
      section(
        review,
        gate_claims,
        :android_foreground_service_backgrounding,
        "artifacts/local-ble/<run-id>/lifecycle/android-foreground-service/",
        [
          "Attach Android logcat for service start, notification visibility, scan/advertise state, app backgrounding, foreground return, stop, close, and visible failure cases."
        ]
      ),
      section(
        review,
        gate_claims,
        :android_background_ble_policy,
        "artifacts/local-ble/<run-id>/lifecycle/android-background-policy.md",
        [
          "Attach Android background scan/advertise policy fixtures and hardware logs for OS throttling, permission, notification, battery, and idle behavior."
        ]
      ),
      section(
        review,
        gate_claims,
        :ios_background_ble_policy,
        "artifacts/local-ble/<run-id>/lifecycle/ios-background-policy.md",
        [
          "Attach Core Bluetooth capability, entitlement, bridge implementation, and replay-normalized iOS background scan or advertise evidence if iOS background participation is required."
        ]
      ),
      section(
        review,
        gate_claims,
        :restart_and_cancellation,
        "artifacts/local-ble/<run-id>/lifecycle/restart-cancellation.md",
        [
          "Attach restart trigger, cancellation, explicit stop, denied-permission, and operator-visible status evidence."
        ]
      ),
      section(
        review,
        gate_claims,
        :scheduled_retry_bounds,
        "artifacts/local-ble/<run-id>/lifecycle/scheduled-retry.md",
        [
          "Attach retry trigger, backoff bounds, maximum attempts, cancellation, skipped, exhausted, and no-guaranteed-delivery evidence."
        ]
      ),
      section(
        review,
        gate_claims,
        :background_gossip_limits,
        "artifacts/local-ble/<run-id>/lifecycle/background-gossip.md",
        [
          "Attach rate limits, TTL/loop policy, battery budget, platform constraints, and multi-device bounded background propagation evidence if required."
        ]
      ),
      section(
        review,
        gate_claims,
        :negative_claim_review,
        "artifacts/local-ble/<run-id>/lifecycle/negative-claims.md",
        [
          "Attach implementation-backed negative fixtures for foreground-only runs, OS throttling, restart cancellation, scheduled retry blocking, background gossip bounds, and release-note wording."
        ]
      )
    ]
  end

  defp section(review, gate_claims, id, artifact_path, notes) do
    %{
      id: id,
      review_section: id,
      artifact_path: artifact_path,
      evidence_type: Map.fetch!(review.required_evidence_types(), id),
      required_entries: [
        :artifact_path,
        :summary,
        :test_command,
        :evidence_type,
        :blocked_claims_called_out
      ],
      blocked_claims_called_out: review.required_blocked_claims(),
      gate_specific_blocked_claims_called_out: Map.get(gate_claims, id, []),
      notes: notes
    }
  end

  defp review_commands do
    [
      "mix meshx.mobile.local_lifecycle.hardware_review --template --out artifacts/local-ble/<run-id>/lifecycle/evidence.json",
      "mix meshx.mobile.local_lifecycle.hardware_review --input artifacts/local-ble/<run-id>/lifecycle/evidence.json --json --out tmp/local-lifecycle-hardware-review.json"
    ]
  end
end
