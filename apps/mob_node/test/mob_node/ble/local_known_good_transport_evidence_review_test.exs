defmodule Mob.Node.BLE.LocalKnownGoodTransportEvidenceReviewTest do
  use ExUnit.Case, async: true

  alias Mob.Node.BLE.LocalKnownGoodTransportEvidenceReview

  test "empty evidence remains open and lists all known-good transport gates" do
    review = LocalKnownGoodTransportEvidenceReview.review(%{})

    assert review.review_version == 1
    assert review.boundary == :known_good_transport_evidence_review
    assert review.status == :open
    refute review.known_good_transport_evidence_complete?
    refute review.known_good_transport_claim_allowed?
    refute review.gatt_fetch_success_claim_allowed?
    refute review.full_message_resolution_claim_allowed?
    refute review.message_delivery_claim_allowed?

    for gate <- LocalKnownGoodTransportEvidenceReview.required_gates() do
      assert Enum.any?(review.missing, &String.contains?(&1, "#{gate} missing artifact_path"))
    end
  end

  test "complete string-keyed metadata is ready without enabling transport claims" do
    review = LocalKnownGoodTransportEvidenceReview.review(complete_json_input())

    assert review.status == :ready
    assert review.known_good_transport_evidence_complete?
    refute review.known_good_transport_claim_allowed?
    refute review.gatt_fetch_success_claim_allowed?
    refute review.full_message_resolution_claim_allowed?
    assert review.missing == []
  end

  test "JSON review keeps known-good transport claims blocked" do
    review = LocalKnownGoodTransportEvidenceReview.json_review(complete_json_input())

    assert review["status"] == "ready"
    assert review["known_good_transport_evidence_complete?"] == true
    assert review["known_good_transport_claim_allowed?"] == false
    assert review["gatt_fetch_success_claim_allowed?"] == false
    assert review["transport_validation_plan"]["current_validated_fetch_transport"] == "none"
  end

  test "template input lists every gate but remains incomplete" do
    template = LocalKnownGoodTransportEvidenceReview.template_input()

    assert Map.keys(template) |> Enum.sort() ==
             LocalKnownGoodTransportEvidenceReview.required_gates()
             |> Enum.map(&Atom.to_string/1)
             |> Enum.sort()

    for gate <- LocalKnownGoodTransportEvidenceReview.required_gates() do
      item = Map.fetch!(template, Atom.to_string(gate))

      assert item["artifact_path"] == ""
      assert item["summary"] == ""
      assert item["test_command"] == ""
      assert item["blocked_claims_called_out"] == []
    end

    review = LocalKnownGoodTransportEvidenceReview.review(template)

    assert review.status == :open
    refute review.known_good_transport_evidence_complete?
    refute review.known_good_transport_claim_allowed?
    refute review.gatt_fetch_success_claim_allowed?
    refute review.full_message_resolution_claim_allowed?
    refute review.message_delivery_claim_allowed?
  end

  test "malformed metadata identifies missing fields and blocked claim callouts" do
    input =
      complete_json_input()
      |> put_in(["candidate_transport_decision", "artifact_path"], "")
      |> put_in(["standalone_interop_matrix", "blocked_claims_called_out"], [
        "known_good_transport"
      ])

    review = LocalKnownGoodTransportEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "candidate_transport_decision missing artifact_path")
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "standalone_interop_matrix missing blocked claim callouts")
           )
  end

  test "omitted known-good transport gate sections are explicit review failures" do
    input = Map.delete(complete_json_input(), "candidate_transport_decision")

    review = LocalKnownGoodTransportEvidenceReview.review(input)

    assert review.status == :open
    refute review.known_good_transport_evidence_complete?

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "candidate_transport_decision evidence section missing")
           )
  end

  test "malformed known-good transport gate sections fail closed without raising" do
    input = Map.put(complete_json_input(), "candidate_transport_decision", "not-an-object")

    review = LocalKnownGoodTransportEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "candidate_transport_decision evidence section must be an object"
             )
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "candidate_transport_decision missing artifact_path")
           )
  end

  test "blocked claim callouts must be a list" do
    input =
      complete_json_input()
      |> put_in(["candidate_transport_decision", "blocked_claims_called_out"], "message_delivery")

    review = LocalKnownGoodTransportEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "candidate_transport_decision blocked_claims_called_out must be a list"
             )
           )
  end

  test "known-good transport evidence artifact paths must be release-relative" do
    input =
      complete_json_input()
      |> put_in(["candidate_transport_decision", "artifact_path"], "/tmp/transport.md")
      |> put_in(["standalone_interop_matrix", "artifact_path"], "../outside/interop.md")
      |> put_in(["tiny_read_write_probe", "artifact_path"], "file:///tmp/tiny.md")
      |> put_in(
        ["known_bad_pair_separation", "artifact_path"],
        "https://example.invalid/known-bad.md"
      )
      |> put_in(["constrained_fetch_prerequisite", "artifact_path"], "~/fetch.md")

    review = LocalKnownGoodTransportEvidenceReview.review(input)

    assert review.status == :open

    for gate <- [
          :candidate_transport_decision,
          :standalone_interop_matrix,
          :tiny_read_write_probe,
          :known_bad_pair_separation,
          :constrained_fetch_prerequisite
        ] do
      assert Enum.any?(
               review.missing,
               &String.contains?(&1, "#{gate} artifact_path must be a relative artifact path.")
             )
    end
  end

  test "known-good transport evidence text fields must be strings and not need trimming" do
    input =
      complete_json_input()
      |> put_in(["candidate_transport_decision", "artifact_path"], 123)
      |> put_in(["standalone_interop_matrix", "summary"], 456)
      |> put_in(["tiny_read_write_probe", "test_command"], 789)
      |> put_in(
        ["known_bad_pair_separation", "artifact_path"],
        " artifacts/local-ble/run/transport/known-bad.md"
      )
      |> put_in(["constrained_fetch_prerequisite", "summary"], " fetch evidence attached ")
      |> put_in(["release_artifact_linkage", "test_command"], " mix test transport ")

    review = LocalKnownGoodTransportEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "candidate_transport_decision artifact_path must be a string.")
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "standalone_interop_matrix summary must be a string.")
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "tiny_read_write_probe test_command must be a string.")
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "known_bad_pair_separation artifact_path must not have leading or trailing whitespace."
             )
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "constrained_fetch_prerequisite summary must not have leading or trailing whitespace."
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

  test "ready metadata must call out gate-specific transport blockers" do
    input =
      complete_json_input()
      |> put_in(
        ["candidate_transport_decision", "blocked_claims_called_out"],
        Enum.map(
          LocalKnownGoodTransportEvidenceReview.required_blocked_claims(),
          &Atom.to_string/1
        )
      )

    review = LocalKnownGoodTransportEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "candidate_transport_decision missing gate-specific blocked claim callouts"
             )
           )
  end

  defp complete_json_input do
    gate_claims = LocalKnownGoodTransportEvidenceReview.required_gate_blocked_claims()

    Map.new(LocalKnownGoodTransportEvidenceReview.required_gates(), fn gate ->
      {Atom.to_string(gate),
       %{
         "artifact_path" => "artifacts/local-ble/run/transport/#{gate}.md",
         "summary" => "#{gate} evidence attached",
         "test_command" => "mix test",
         "blocked_claims_called_out" =>
           (LocalKnownGoodTransportEvidenceReview.required_blocked_claims() ++
              Map.get(gate_claims, gate, []))
           |> Enum.uniq()
           |> Enum.map(&Atom.to_string/1)
       }}
    end)
  end
end
