defmodule MeshxMobileApp.BLE.LocalFullMessageResolutionEvidenceReviewTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.LocalFullMessageResolutionEvidenceReview

  test "empty evidence remains open and lists all transport gates" do
    review = LocalFullMessageResolutionEvidenceReview.review(%{})

    assert review.review_version == 1
    assert review.boundary == :full_message_resolution_transport_evidence_review
    assert review.status == :open
    refute review.full_resolution_transport_evidence_complete?
    refute review.real_fetch_transport_validated?
    refute review.full_message_resolution_claim_allowed?
    refute review.known_good_transport_claim_allowed?
    refute review.message_delivery_claim_allowed?
    refute review.trusted_message_claim_allowed?

    for gate <- LocalFullMessageResolutionEvidenceReview.required_gates() do
      assert Enum.any?(review.missing, &String.contains?(&1, "#{gate} missing artifact_path"))
    end
  end

  test "complete string-keyed metadata is ready without enabling resolution claims" do
    review = LocalFullMessageResolutionEvidenceReview.review(complete_json_input())

    assert review.status == :ready
    assert review.full_resolution_transport_evidence_complete?
    refute review.real_fetch_transport_validated?
    refute review.full_message_resolution_claim_allowed?
    refute review.message_delivery_claim_allowed?
    assert review.missing == []
  end

  test "JSON review is machine readable and keeps transport claims blocked" do
    review = LocalFullMessageResolutionEvidenceReview.json_review(complete_json_input())

    assert review["status"] == "ready"
    assert review["full_resolution_transport_evidence_complete?"] == true
    assert review["real_fetch_transport_validated?"] == false
    assert review["message_delivery_claim_allowed?"] == false
    assert review["transport_validation_plan"]["current_validated_fetch_transport"] == "none"
  end

  test "template input lists every gate but remains incomplete" do
    template = LocalFullMessageResolutionEvidenceReview.template_input()

    assert Map.keys(template) |> Enum.sort() ==
             LocalFullMessageResolutionEvidenceReview.required_gates()
             |> Enum.map(&Atom.to_string/1)
             |> Enum.sort()

    for gate <- LocalFullMessageResolutionEvidenceReview.required_gates() do
      item = Map.fetch!(template, Atom.to_string(gate))

      assert item["artifact_path"] == ""
      assert item["summary"] == ""
      assert item["test_command"] == ""
      assert item["blocked_claims_called_out"] == []
    end

    review = LocalFullMessageResolutionEvidenceReview.review(template)

    assert review.status == :open
    refute review.full_resolution_transport_evidence_complete?
    refute review.real_fetch_transport_validated?
    refute review.full_message_resolution_claim_allowed?
    refute review.known_good_transport_claim_allowed?
    refute review.gatt_fetch_success_claim_allowed?
    refute review.message_delivery_claim_allowed?
    refute review.trusted_message_claim_allowed?
  end

  test "malformed metadata identifies missing fields and blocked claim callouts" do
    input =
      complete_json_input()
      |> put_in(["candidate_transport_decision", "artifact_path"], "")
      |> put_in(["standalone_interop_matrix", "blocked_claims_called_out"], [
        "full_message_resolution"
      ])

    review = LocalFullMessageResolutionEvidenceReview.review(input)

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

  test "omitted full-resolution gate sections are explicit review failures" do
    input = Map.delete(complete_json_input(), "candidate_transport_decision")

    review = LocalFullMessageResolutionEvidenceReview.review(input)

    assert review.status == :open
    refute review.full_resolution_transport_evidence_complete?

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "candidate_transport_decision evidence section missing")
           )
  end

  test "malformed full-resolution gate sections fail closed without raising" do
    input = Map.put(complete_json_input(), "candidate_transport_decision", "not-an-object")

    review = LocalFullMessageResolutionEvidenceReview.review(input)

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
      |> put_in(["candidate_transport_decision", "blocked_claims_called_out"], "fake_success")

    review = LocalFullMessageResolutionEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "candidate_transport_decision blocked_claims_called_out must be a list"
             )
           )
  end

  test "full-resolution evidence artifact paths must be release-relative" do
    input =
      complete_json_input()
      |> put_in(["current_gatt_blocker_recorded", "artifact_path"], "/tmp/gatt-blocker.md")
      |> put_in(["candidate_transport_decision", "artifact_path"], "../outside/transport.md")
      |> put_in(["standalone_interop_matrix", "artifact_path"], "file:///tmp/interop.md")
      |> put_in(
        ["constrained_fetch_exchange", "artifact_path"],
        "https://example.invalid/fetch.md"
      )
      |> put_in(["canonical_replay_resolution", "artifact_path"], "~/resolution.md")

    review = LocalFullMessageResolutionEvidenceReview.review(input)

    assert review.status == :open

    for gate <- [
          :current_gatt_blocker_recorded,
          :candidate_transport_decision,
          :standalone_interop_matrix,
          :constrained_fetch_exchange,
          :canonical_replay_resolution
        ] do
      assert Enum.any?(
               review.missing,
               &String.contains?(&1, "#{gate} artifact_path must be a relative artifact path.")
             )
    end
  end

  test "full-resolution evidence text fields must be strings and not need trimming" do
    input =
      complete_json_input()
      |> put_in(["current_gatt_blocker_recorded", "artifact_path"], 123)
      |> put_in(["candidate_transport_decision", "summary"], 456)
      |> put_in(["standalone_interop_matrix", "test_command"], 789)
      |> put_in(
        ["constrained_fetch_exchange", "artifact_path"],
        " artifacts/local-ble/run/full-resolution/fetch.md"
      )
      |> put_in(["canonical_replay_resolution", "summary"], " replay evidence attached ")
      |> put_in(["release_artifact_linkage", "test_command"], " mix test fetch ")

    review = LocalFullMessageResolutionEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "current_gatt_blocker_recorded artifact_path must be a string."
             )
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "candidate_transport_decision summary must be a string.")
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "standalone_interop_matrix test_command must be a string.")
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "constrained_fetch_exchange artifact_path must not have leading or trailing whitespace."
             )
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "canonical_replay_resolution summary must not have leading or trailing whitespace."
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

  test "ready metadata must call out gate-specific resolution blockers" do
    input =
      complete_json_input()
      |> put_in(
        ["canonical_replay_resolution", "blocked_claims_called_out"],
        Enum.map(
          LocalFullMessageResolutionEvidenceReview.required_blocked_claims(),
          &Atom.to_string/1
        )
      )

    review = LocalFullMessageResolutionEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "canonical_replay_resolution missing gate-specific blocked claim callouts"
             )
           )
  end

  defp complete_json_input do
    gate_claims = LocalFullMessageResolutionEvidenceReview.required_gate_blocked_claims()

    Map.new(LocalFullMessageResolutionEvidenceReview.required_gates(), fn gate ->
      {Atom.to_string(gate),
       %{
         "artifact_path" => "artifacts/local-ble/run/full-resolution/#{gate}.md",
         "summary" => "#{gate} evidence attached",
         "test_command" => "mix test",
         "blocked_claims_called_out" =>
           (LocalFullMessageResolutionEvidenceReview.required_blocked_claims() ++
              Map.get(gate_claims, gate, []))
           |> Enum.uniq()
           |> Enum.map(&Atom.to_string/1)
       }}
    end)
  end
end
