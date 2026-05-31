defmodule Mob.Node.BLE.LocalMultiHopHardwareEvidenceReviewTest do
  use ExUnit.Case, async: true

  alias Mob.Node.BLE.LocalMultiHopHardwareEvidenceReview

  test "empty evidence remains open and lists all multi-hop hardware gates" do
    review = LocalMultiHopHardwareEvidenceReview.review(%{})

    assert review.review_version == 1
    assert review.boundary == :multi_hop_hardware_evidence_review
    assert review.status == :open
    refute review.multi_hop_hardware_evidence_complete?
    refute review.multi_hop_physical_proof_present?
    refute review.multi_hop_hardware_gossip_claim_allowed?
    refute review.routed_delivery_claim_allowed?
    refute review.guaranteed_delivery_claim_allowed?
    refute review.trusted_delivery_claim_allowed?
    refute review.background_operation_claim_allowed?

    for gate <- LocalMultiHopHardwareEvidenceReview.required_gates() do
      assert Enum.any?(review.missing, &String.contains?(&1, "#{gate} missing artifact_path"))
    end
  end

  test "complete string-keyed metadata is ready without enabling multi-hop claims" do
    review = LocalMultiHopHardwareEvidenceReview.review(complete_json_input())

    assert review.status == :ready
    assert review.multi_hop_hardware_evidence_complete?
    refute review.multi_hop_physical_proof_present?
    refute review.multi_hop_hardware_gossip_claim_allowed?
    refute review.routed_delivery_claim_allowed?
    assert review.missing == []
  end

  test "JSON review is machine readable and keeps hardware claims blocked" do
    review = LocalMultiHopHardwareEvidenceReview.json_review(complete_json_input())

    assert review["status"] == "ready"
    assert review["multi_hop_hardware_evidence_complete?"] == true
    assert review["multi_hop_physical_proof_present?"] == false
    assert review["routed_delivery_claim_allowed?"] == false

    assert review["validation_plan"]["current_hardware_scope"] ==
             "one_hop_legacy_beacon_gossip_only"
  end

  test "template input lists every gate but remains incomplete" do
    template = LocalMultiHopHardwareEvidenceReview.template_input()

    assert Map.keys(template) |> Enum.sort() ==
             LocalMultiHopHardwareEvidenceReview.required_gates()
             |> Enum.map(&Atom.to_string/1)
             |> Enum.sort()

    for gate <- LocalMultiHopHardwareEvidenceReview.required_gates() do
      item = Map.fetch!(template, Atom.to_string(gate))

      assert item["artifact_path"] == ""
      assert item["summary"] == ""
      assert item["test_command"] == ""
      assert item["blocked_claims_called_out"] == []
    end

    review = LocalMultiHopHardwareEvidenceReview.review(template)

    assert review.status == :open
    refute review.multi_hop_hardware_evidence_complete?
    refute review.multi_hop_physical_proof_present?
    refute review.multi_hop_hardware_gossip_claim_allowed?
    refute review.routed_delivery_claim_allowed?
    refute review.guaranteed_delivery_claim_allowed?
    refute review.trusted_delivery_claim_allowed?
    refute review.background_operation_claim_allowed?
  end

  test "malformed metadata identifies missing fields and blocked claim callouts" do
    input =
      complete_json_input()
      |> put_in(["three_role_device_matrix", "artifact_path"], "")
      |> put_in(["origin_relay_observer_capture", "blocked_claims_called_out"], [
        "multi_hop_hardware_gossip"
      ])

    review = LocalMultiHopHardwareEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "three_role_device_matrix missing artifact_path")
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "origin_relay_observer_capture missing blocked claim callouts")
           )
  end

  test "omitted multi-hop gate sections are explicit review failures" do
    input = Map.delete(complete_json_input(), "three_role_device_matrix")

    review = LocalMultiHopHardwareEvidenceReview.review(input)

    assert review.status == :open
    refute review.multi_hop_hardware_evidence_complete?

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "three_role_device_matrix evidence section missing")
           )
  end

  test "malformed multi-hop gate sections fail closed without raising" do
    input = Map.put(complete_json_input(), "three_role_device_matrix", "not-an-object")

    review = LocalMultiHopHardwareEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "three_role_device_matrix evidence section must be an object")
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "three_role_device_matrix missing artifact_path")
           )
  end

  test "blocked claim callouts must be a list" do
    input =
      complete_json_input()
      |> put_in(["three_role_device_matrix", "blocked_claims_called_out"], "routed_delivery")

    review = LocalMultiHopHardwareEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "three_role_device_matrix blocked_claims_called_out must be a list"
             )
           )
  end

  test "multi-hop evidence artifact paths must be release-relative" do
    input =
      complete_json_input()
      |> put_in(["three_role_device_matrix", "artifact_path"], "/tmp/multi-hop/devices.md")
      |> put_in(
        ["origin_relay_observer_capture", "artifact_path"],
        "../outside/capture.md"
      )
      |> put_in(["replay_normalized_fixture", "artifact_path"], "file:///tmp/replay.md")
      |> put_in(
        ["ttl_and_suppression_evidence", "artifact_path"],
        "https://example.invalid/ttl.md"
      )
      |> put_in(["one_hop_negative_review", "artifact_path"], "~/one-hop.md")

    review = LocalMultiHopHardwareEvidenceReview.review(input)

    assert review.status == :open

    for gate <- [
          :three_role_device_matrix,
          :origin_relay_observer_capture,
          :replay_normalized_fixture,
          :ttl_and_suppression_evidence,
          :one_hop_negative_review
        ] do
      assert Enum.any?(
               review.missing,
               &String.contains?(&1, "#{gate} artifact_path must be a relative artifact path.")
             )
    end
  end

  test "multi-hop evidence text fields must be strings and not need trimming" do
    input =
      complete_json_input()
      |> put_in(["three_role_device_matrix", "artifact_path"], 123)
      |> put_in(["origin_relay_observer_capture", "summary"], 456)
      |> put_in(["replay_normalized_fixture", "test_command"], 789)
      |> put_in(
        ["ttl_and_suppression_evidence", "artifact_path"],
        " artifacts/local-ble/run/multi-hop/ttl.md"
      )
      |> put_in(["one_hop_negative_review", "summary"], " one-hop evidence attached ")
      |> put_in(["release_artifact_linkage", "test_command"], " mix test multi-hop ")

    review = LocalMultiHopHardwareEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "three_role_device_matrix artifact_path must be a string.")
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "origin_relay_observer_capture summary must be a string.")
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "replay_normalized_fixture test_command must be a string.")
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "ttl_and_suppression_evidence artifact_path must not have leading or trailing whitespace."
             )
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "one_hop_negative_review summary must not have leading or trailing whitespace."
             )
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "release_artifact_linkage test_command must not have leading or trailing whitespace."
             )
           )
  end

  test "ready metadata must call out gate-specific multi-hop blockers" do
    input =
      complete_json_input()
      |> put_in(
        ["one_hop_negative_review", "blocked_claims_called_out"],
        Enum.map(
          LocalMultiHopHardwareEvidenceReview.required_blocked_claims(),
          &Atom.to_string/1
        )
      )

    review = LocalMultiHopHardwareEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "one_hop_negative_review missing gate-specific blocked claim callouts"
             )
           )
  end

  defp complete_json_input do
    gate_claims = LocalMultiHopHardwareEvidenceReview.required_gate_blocked_claims()

    Map.new(LocalMultiHopHardwareEvidenceReview.required_gates(), fn gate ->
      {Atom.to_string(gate),
       %{
         "artifact_path" => "artifacts/local-ble/run/multi-hop/#{gate}.md",
         "summary" => "#{gate} evidence attached",
         "test_command" => "mix test",
         "blocked_claims_called_out" =>
           (LocalMultiHopHardwareEvidenceReview.required_blocked_claims() ++
              Map.get(gate_claims, gate, []))
           |> Enum.uniq()
           |> Enum.map(&Atom.to_string/1)
       }}
    end)
  end
end
