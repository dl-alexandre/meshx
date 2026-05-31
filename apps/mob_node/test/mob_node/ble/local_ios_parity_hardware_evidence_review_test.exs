defmodule Mob.Node.BLE.LocalIOSParityHardwareEvidenceReviewTest do
  use ExUnit.Case, async: true

  alias Mob.Node.BLE.LocalIOSParityHardwareEvidenceReview

  test "empty evidence remains open and lists all iOS hardware gates" do
    review = LocalIOSParityHardwareEvidenceReview.review(%{})

    assert review.review_version == 1
    assert review.boundary == :ios_advert_only_hardware_evidence_review
    assert review.status == :open
    refute review.ios_hardware_evidence_complete?
    refute review.ios_participation_claim_allowed?
    refute review.ios_hardware_claim_allowed?
    refute review.ios_legacy_beacon_observe_claim_allowed?
    refute review.ios_legacy_beacon_gossip_claim_allowed?
    refute review.ios_full_envelope_advert_claim_allowed?
    refute review.ios_background_ble_claim_allowed?
    refute review.ios_parity_claim_allowed?

    for gate <- LocalIOSParityHardwareEvidenceReview.required_gates() do
      assert Enum.any?(review.missing, &String.contains?(&1, "#{gate} missing artifact_path"))
    end
  end

  test "complete string-keyed metadata is ready without enabling iOS claims" do
    review = LocalIOSParityHardwareEvidenceReview.review(complete_json_input())

    assert review.status == :ready
    assert review.ios_hardware_evidence_complete?
    refute review.ios_participation_claim_allowed?
    refute review.ios_legacy_beacon_gossip_claim_allowed?
    refute review.ios_parity_claim_allowed?
    assert review.missing == []

    assert Map.keys(review.evidence_by_gate) |> Enum.sort() ==
             LocalIOSParityHardwareEvidenceReview.required_gates() |> Enum.sort()
  end

  test "JSON review is machine readable and keeps iOS participation blocked" do
    review = LocalIOSParityHardwareEvidenceReview.json_review(complete_json_input())

    assert review["status"] == "ready"
    assert review["ios_hardware_evidence_complete?"] == true
    assert review["ios_participation_claim_allowed?"] == false
    assert review["ios_background_ble_claim_allowed?"] == false
    assert review["ios_parity_claim_allowed?"] == false
    assert review["hardware_validation_plan"]["current_ios_mode"] == "contract_only"
  end

  test "template input lists every gate but remains incomplete" do
    template = LocalIOSParityHardwareEvidenceReview.template_input()

    assert Map.keys(template) |> Enum.sort() ==
             LocalIOSParityHardwareEvidenceReview.required_gates()
             |> Enum.map(&Atom.to_string/1)
             |> Enum.sort()

    for gate <- LocalIOSParityHardwareEvidenceReview.required_gates() do
      item = Map.fetch!(template, Atom.to_string(gate))

      assert item["artifact_path"] == ""
      assert item["summary"] == ""
      assert item["test_command"] == ""

      assert item["evidence_type"] ==
               LocalIOSParityHardwareEvidenceReview.required_evidence_types()
               |> Map.fetch!(gate)
               |> Atom.to_string()

      assert item["blocked_claims_called_out"] == []
    end

    review = LocalIOSParityHardwareEvidenceReview.review(template)

    assert review.status == :open
    refute review.ios_hardware_evidence_complete?
    refute review.ios_participation_claim_allowed?
    refute review.ios_legacy_beacon_observe_claim_allowed?
    refute review.ios_legacy_beacon_gossip_claim_allowed?
    refute review.ios_full_envelope_advert_claim_allowed?
    refute review.ios_background_ble_claim_allowed?
    refute review.ios_parity_claim_allowed?
  end

  test "malformed metadata identifies missing fields and blocked claim callouts" do
    input =
      complete_json_input()
      |> put_in(["target_ios_device_matrix", "artifact_path"], "")
      |> put_in(["legacy_beacon_observe_hardware", "blocked_claims_called_out"], [
        "ios_hardware_participation"
      ])
      |> put_in(["full_envelope_capability_probe", "evidence_type"], nil)

    review = LocalIOSParityHardwareEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "target_ios_device_matrix missing artifact_path")
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "legacy_beacon_observe_hardware missing blocked claim callouts"
             )
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "full_envelope_capability_probe missing evidence_type")
           )
  end

  test "omitted iOS hardware gate sections are explicit review failures" do
    input = Map.delete(complete_json_input(), "target_ios_device_matrix")

    review = LocalIOSParityHardwareEvidenceReview.review(input)

    assert review.status == :open
    refute review.ios_hardware_evidence_complete?

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "target_ios_device_matrix evidence section missing")
           )
  end

  test "malformed iOS hardware gate sections fail closed without raising" do
    input = Map.put(complete_json_input(), "target_ios_device_matrix", "not-an-object")

    review = LocalIOSParityHardwareEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "target_ios_device_matrix evidence section must be an object")
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "target_ios_device_matrix missing artifact_path")
           )
  end

  test "blocked claim callouts must be a list" do
    input =
      complete_json_input()
      |> put_in(["target_ios_device_matrix", "blocked_claims_called_out"], "ios_parity_claim")

    review = LocalIOSParityHardwareEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "target_ios_device_matrix blocked_claims_called_out must be a list"
             )
           )
  end

  test "ready metadata must use the required evidence type for each iOS gate" do
    input =
      complete_json_input()
      |> put_in(["legacy_beacon_gossip_hardware", "evidence_type"], "canonical_ingress_fixture")

    review = LocalIOSParityHardwareEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "legacy_beacon_gossip_hardware evidence_type must be :legacy_beacon_gossip_hardware"
             )
           )
  end

  test "iOS hardware evidence artifact paths must be release-relative" do
    input =
      complete_json_input()
      |> put_in(["target_ios_device_matrix", "artifact_path"], "/tmp/ios/devices.md")
      |> put_in(["canonical_ingress_fixture", "artifact_path"], "../outside/ingress.md")
      |> put_in(["legacy_beacon_observe_hardware", "artifact_path"], "file:///tmp/observe.md")
      |> put_in(
        ["legacy_beacon_gossip_hardware", "artifact_path"],
        "https://example.invalid/gossip.md"
      )
      |> put_in(["full_envelope_capability_probe", "artifact_path"], "~/ios/probe.md")

    review = LocalIOSParityHardwareEvidenceReview.review(input)

    assert review.status == :open

    for gate <- [
          :target_ios_device_matrix,
          :canonical_ingress_fixture,
          :legacy_beacon_observe_hardware,
          :legacy_beacon_gossip_hardware,
          :full_envelope_capability_probe
        ] do
      assert Enum.any?(
               review.missing,
               &String.contains?(&1, "#{gate} artifact_path must be a relative artifact path.")
             )
    end
  end

  test "iOS hardware evidence text fields must be strings and not need trimming" do
    input =
      complete_json_input()
      |> put_in(["target_ios_device_matrix", "artifact_path"], 123)
      |> put_in(["canonical_ingress_fixture", "summary"], 456)
      |> put_in(["legacy_beacon_observe_hardware", "test_command"], 789)
      |> put_in(
        ["legacy_beacon_gossip_hardware", "artifact_path"],
        " artifacts/local-ble/run/ios/gossip.md"
      )
      |> put_in(["full_envelope_capability_probe", "summary"], " probe evidence attached ")
      |> put_in(["negative_claim_review", "test_command"], " mix test ios ")

    review = LocalIOSParityHardwareEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "target_ios_device_matrix artifact_path must be a string.")
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "canonical_ingress_fixture summary must be a string.")
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "legacy_beacon_observe_hardware test_command must be a string."
             )
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "legacy_beacon_gossip_hardware artifact_path must not have leading or trailing whitespace."
             )
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "full_envelope_capability_probe summary must not have leading or trailing whitespace."
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

  test "ready metadata must call out gate-specific iOS blockers" do
    input =
      complete_json_input()
      |> put_in(
        ["legacy_beacon_gossip_hardware", "blocked_claims_called_out"],
        Enum.map(
          LocalIOSParityHardwareEvidenceReview.required_blocked_claims(),
          &Atom.to_string/1
        )
      )

    review = LocalIOSParityHardwareEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "legacy_beacon_gossip_hardware missing gate-specific blocked claim callouts"
             )
           )
  end

  defp complete_json_input do
    gate_claims = LocalIOSParityHardwareEvidenceReview.required_gate_blocked_claims()

    Map.new(LocalIOSParityHardwareEvidenceReview.required_gates(), fn gate ->
      {Atom.to_string(gate),
       %{
         "artifact_path" => "artifacts/local-ble/run/ios/#{gate}.md",
         "summary" => "#{gate} evidence attached",
         "test_command" =>
           "mix test apps/mob_node/test/mob_node/ble/local_ios_parity_#{gate}_test.exs",
         "evidence_type" =>
           LocalIOSParityHardwareEvidenceReview.required_evidence_types()
           |> Map.fetch!(gate)
           |> Atom.to_string(),
         "blocked_claims_called_out" =>
           (LocalIOSParityHardwareEvidenceReview.required_blocked_claims() ++
              Map.get(gate_claims, gate, []))
           |> Enum.uniq()
           |> Enum.map(&Atom.to_string/1)
       }}
    end)
  end
end
