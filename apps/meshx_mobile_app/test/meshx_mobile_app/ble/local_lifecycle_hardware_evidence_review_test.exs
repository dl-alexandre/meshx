defmodule MeshxMobileApp.BLE.LocalLifecycleHardwareEvidenceReviewTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.LocalLifecycleHardwareEvidenceReview

  test "empty evidence remains open and lists all lifecycle gates" do
    review = LocalLifecycleHardwareEvidenceReview.review(%{})

    assert review.review_version == 1
    assert review.boundary == :mobile_ble_lifecycle_hardware_evidence_review
    assert review.status == :open
    refute review.lifecycle_hardware_evidence_complete?
    refute review.android_foreground_service_claim_allowed?
    refute review.background_ble_claim_allowed?
    refute review.restart_claim_allowed?
    refute review.scheduled_retry_claim_allowed?
    refute review.background_gossip_claim_allowed?
    refute review.delivery_claim_allowed?

    for gate <- LocalLifecycleHardwareEvidenceReview.required_gates() do
      assert Enum.any?(review.missing, &String.contains?(&1, "#{gate} missing artifact_path"))
    end
  end

  test "complete string-keyed metadata is ready without enabling lifecycle claims" do
    review = LocalLifecycleHardwareEvidenceReview.review(complete_json_input())

    assert review.status == :ready
    assert review.lifecycle_hardware_evidence_complete?
    refute review.android_foreground_service_claim_allowed?
    refute review.background_ble_claim_allowed?
    refute review.delivery_claim_allowed?
    assert review.missing == []

    assert Map.keys(review.evidence_by_gate) |> Enum.sort() ==
             LocalLifecycleHardwareEvidenceReview.required_gates() |> Enum.sort()
  end

  test "JSON review is machine readable and keeps background claims blocked" do
    review = LocalLifecycleHardwareEvidenceReview.json_review(complete_json_input())

    assert review["status"] == "ready"
    assert review["lifecycle_hardware_evidence_complete?"] == true
    assert review["background_ble_claim_allowed?"] == false
    assert review["restart_claim_allowed?"] == false
    assert review["delivery_claim_allowed?"] == false
    assert review["hardware_validation_plan"]["current_validated_mode"] == "foreground_manual"
  end

  test "template input lists every gate but remains incomplete" do
    template = LocalLifecycleHardwareEvidenceReview.template_input()

    assert Map.keys(template) |> Enum.sort() ==
             LocalLifecycleHardwareEvidenceReview.required_gates()
             |> Enum.map(&Atom.to_string/1)
             |> Enum.sort()

    for gate <- LocalLifecycleHardwareEvidenceReview.required_gates() do
      item = Map.fetch!(template, Atom.to_string(gate))

      assert item["artifact_path"] == ""
      assert item["summary"] == ""
      assert item["test_command"] == ""

      assert item["evidence_type"] ==
               LocalLifecycleHardwareEvidenceReview.required_evidence_types()
               |> Map.fetch!(gate)
               |> Atom.to_string()

      assert item["blocked_claims_called_out"] == []
    end

    review = LocalLifecycleHardwareEvidenceReview.review(template)

    assert review.status == :open
    refute review.lifecycle_hardware_evidence_complete?
    refute review.android_foreground_service_claim_allowed?
    refute review.background_ble_claim_allowed?
    refute review.restart_claim_allowed?
    refute review.scheduled_retry_claim_allowed?
    refute review.background_gossip_claim_allowed?
    refute review.delivery_claim_allowed?
  end

  test "malformed metadata identifies missing fields and blocked claim callouts" do
    input =
      complete_json_input()
      |> put_in(["target_device_matrix", "artifact_path"], "")
      |> put_in(["android_background_ble_policy", "blocked_claims_called_out"], [
        "android_background_scan"
      ])
      |> put_in(["scheduled_retry_bounds", "evidence_type"], nil)

    review = LocalLifecycleHardwareEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "target_device_matrix missing artifact_path")
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "android_background_ble_policy missing blocked claim callouts")
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "scheduled_retry_bounds missing evidence_type")
           )
  end

  test "omitted lifecycle gate sections are explicit review failures" do
    input = Map.delete(complete_json_input(), "target_device_matrix")

    review = LocalLifecycleHardwareEvidenceReview.review(input)

    assert review.status == :open
    refute review.lifecycle_hardware_evidence_complete?

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "target_device_matrix evidence section missing")
           )
  end

  test "malformed lifecycle gate sections fail closed without raising" do
    input = Map.put(complete_json_input(), "target_device_matrix", "not-an-object")

    review = LocalLifecycleHardwareEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "target_device_matrix evidence section must be an object")
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "target_device_matrix missing artifact_path")
           )
  end

  test "blocked claim callouts must be a list" do
    input =
      complete_json_input()
      |> put_in(["target_device_matrix", "blocked_claims_called_out"], "background_delivery")

    review = LocalLifecycleHardwareEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "target_device_matrix blocked_claims_called_out must be a list"
             )
           )
  end

  test "ready metadata must use the required evidence type for each lifecycle gate" do
    input =
      complete_json_input()
      |> put_in(
        ["android_foreground_service_backgrounding", "evidence_type"],
        "target_device_matrix"
      )

    review = LocalLifecycleHardwareEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "android_foreground_service_backgrounding evidence_type must be :android_foreground_service_log"
             )
           )
  end

  test "lifecycle evidence artifact paths must be release-relative" do
    input =
      complete_json_input()
      |> put_in(["target_device_matrix", "artifact_path"], "/tmp/lifecycle/devices.md")
      |> put_in(
        ["android_foreground_service_backgrounding", "artifact_path"],
        "../outside/foreground.md"
      )
      |> put_in(["android_background_ble_policy", "artifact_path"], "file:///tmp/android.md")
      |> put_in(
        ["ios_background_ble_policy", "artifact_path"],
        "https://example.invalid/ios.md"
      )
      |> put_in(["restart_and_cancellation", "artifact_path"], "~/restart.md")

    review = LocalLifecycleHardwareEvidenceReview.review(input)

    assert review.status == :open

    for gate <- [
          :target_device_matrix,
          :android_foreground_service_backgrounding,
          :android_background_ble_policy,
          :ios_background_ble_policy,
          :restart_and_cancellation
        ] do
      assert Enum.any?(
               review.missing,
               &String.contains?(&1, "#{gate} artifact_path must be a relative artifact path.")
             )
    end
  end

  test "lifecycle evidence text fields must be strings and not need trimming" do
    input =
      complete_json_input()
      |> put_in(["target_device_matrix", "artifact_path"], 123)
      |> put_in(["android_foreground_service_backgrounding", "summary"], 456)
      |> put_in(["android_background_ble_policy", "test_command"], 789)
      |> put_in(
        ["ios_background_ble_policy", "artifact_path"],
        " artifacts/local-ble/run/lifecycle/ios-policy.md"
      )
      |> put_in(["restart_and_cancellation", "summary"], " restart evidence attached ")
      |> put_in(["negative_claim_review", "test_command"], " mix test lifecycle ")

    review = LocalLifecycleHardwareEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "target_device_matrix artifact_path must be a string.")
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "android_foreground_service_backgrounding summary must be a string."
             )
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "android_background_ble_policy test_command must be a string.")
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "ios_background_ble_policy artifact_path must not have leading or trailing whitespace."
             )
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "restart_and_cancellation summary must not have leading or trailing whitespace."
             )
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "negative_claim_review test_command must not have leading or trailing whitespace."
             )
           )
  end

  test "ready metadata must call out gate-specific lifecycle blockers" do
    input =
      complete_json_input()
      |> put_in(
        ["restart_and_cancellation", "blocked_claims_called_out"],
        Enum.map(
          LocalLifecycleHardwareEvidenceReview.required_blocked_claims(),
          &Atom.to_string/1
        )
      )

    review = LocalLifecycleHardwareEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "restart_and_cancellation missing gate-specific blocked claim callouts"
             )
           )
  end

  defp complete_json_input do
    gate_claims = LocalLifecycleHardwareEvidenceReview.required_gate_blocked_claims()

    Map.new(LocalLifecycleHardwareEvidenceReview.required_gates(), fn gate ->
      {Atom.to_string(gate),
       %{
         "artifact_path" => "artifacts/local-ble/run/lifecycle/#{gate}.md",
         "summary" => "#{gate} evidence attached",
         "test_command" =>
           "mix test apps/meshx_mobile_app/test/meshx_mobile_app/ble/local_lifecycle_#{gate}_test.exs",
         "evidence_type" =>
           LocalLifecycleHardwareEvidenceReview.required_evidence_types()
           |> Map.fetch!(gate)
           |> Atom.to_string(),
         "blocked_claims_called_out" =>
           (LocalLifecycleHardwareEvidenceReview.required_blocked_claims() ++
              Map.get(gate_claims, gate, []))
           |> Enum.uniq()
           |> Enum.map(&Atom.to_string/1)
       }}
    end)
  end
end
