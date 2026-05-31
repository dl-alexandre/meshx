defmodule Mob.Node.BLE.LocalPersistenceProductionEvidenceReviewTest do
  use ExUnit.Case, async: true

  alias Mob.Node.BLE.LocalPersistenceProductionEvidenceReview

  test "empty evidence remains open and lists all production lifecycle gates" do
    review = LocalPersistenceProductionEvidenceReview.review(%{})

    assert review.review_version == 1
    assert review.boundary == :production_default_persistence_evidence_review
    assert review.status == :open
    refute review.production_persistence_evidence_complete?
    refute review.production_default_persistence_allowed?
    refute review.default_persistence_claim_allowed?
    refute review.background_persistence_claim_allowed?
    refute review.delivery_record_claim_allowed?
    refute review.full_message_resolution_claim_allowed?

    for gate <- LocalPersistenceProductionEvidenceReview.required_gates() do
      assert Enum.any?(review.missing, &String.contains?(&1, "#{gate} missing artifact_path"))
    end
  end

  test "omitted production evidence gate sections are explicit" do
    review = LocalPersistenceProductionEvidenceReview.review(%{})

    assert review.status == :open

    for gate <- LocalPersistenceProductionEvidenceReview.required_gates() do
      assert Enum.any?(
               review.missing,
               &String.contains?(&1, "Missing #{gate} evidence section.")
             )
    end
  end

  test "malformed production evidence gate sections fail closed instead of raising" do
    input =
      complete_json_input()
      |> Map.put("schema_migration_policy", "not-an-object")

    review = LocalPersistenceProductionEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "schema_migration_policy evidence section must be an object."
             )
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "schema_migration_policy missing artifact_path")
           )
  end

  test "complete string-keyed metadata is ready without enabling default persistence" do
    review = LocalPersistenceProductionEvidenceReview.review(complete_json_input())

    assert review.status == :ready
    assert review.production_persistence_evidence_complete?
    refute review.production_default_persistence_allowed?
    refute review.delivery_record_claim_allowed?
    assert review.missing == []

    assert Map.keys(review.evidence_by_gate) |> Enum.sort() ==
             LocalPersistenceProductionEvidenceReview.required_gates() |> Enum.sort()
  end

  test "JSON review is machine readable and keeps persistence claims blocked" do
    review = LocalPersistenceProductionEvidenceReview.json_review(complete_json_input())

    assert review["status"] == "ready"
    assert review["production_persistence_evidence_complete?"] == true
    assert review["production_default_persistence_allowed?"] == false
    assert review["delivery_record_claim_allowed?"] == false
    assert review["production_lifecycle_plan"]["current_default_mode"] == "memory_only"
  end

  test "template input lists every gate but cannot pass as complete evidence" do
    template = LocalPersistenceProductionEvidenceReview.template_input()

    assert Map.keys(template) |> Enum.sort() ==
             LocalPersistenceProductionEvidenceReview.required_gates()
             |> Enum.map(&Atom.to_string/1)
             |> Enum.sort()

    for gate <- LocalPersistenceProductionEvidenceReview.required_gates() do
      gate_template = Map.fetch!(template, Atom.to_string(gate))

      assert gate_template["evidence_type"] ==
               LocalPersistenceProductionEvidenceReview.required_evidence_types()
               |> Map.fetch!(gate)
               |> Atom.to_string()

      assert gate_template["artifact_path"] == ""
      assert gate_template["blocked_claims_called_out"] == []
    end

    assert template["default_lifecycle_decision"]["decision_outcome"] == ""

    review = LocalPersistenceProductionEvidenceReview.review(template)

    assert review.status == :open
    refute review.production_persistence_evidence_complete?
    refute review.production_default_persistence_allowed?
  end

  test "default lifecycle decision must declare the product decision outcome" do
    input =
      complete_json_input()
      |> update_in(["default_lifecycle_decision"], &Map.delete(&1, "decision_outcome"))

    review = LocalPersistenceProductionEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "default_lifecycle_decision missing decision_outcome")
           )
  end

  test "default lifecycle decision outcome is constrained" do
    input =
      complete_json_input()
      |> put_in(["default_lifecycle_decision", "decision_outcome"], "maybe_enable_it")

    review = LocalPersistenceProductionEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "default_lifecycle_decision decision_outcome must be one of")
           )
  end

  test "malformed metadata identifies missing fields and blocked claim callouts" do
    input =
      complete_json_input()
      |> put_in(["schema_migration_policy", "artifact_path"], "")
      |> put_in(["scheduled_cleanup_worker", "blocked_claims_called_out"], ["delivery_record"])
      |> put_in(["background_safe_writer", "evidence_type"], nil)

    review = LocalPersistenceProductionEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "schema_migration_policy missing artifact_path")
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "scheduled_cleanup_worker missing blocked claim callouts")
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "background_safe_writer missing evidence_type")
           )
  end

  test "blocked claim callouts must be listed explicitly" do
    input =
      complete_json_input()
      |> put_in(["scheduled_cleanup_worker", "blocked_claims_called_out"], "delivery_record")

    review = LocalPersistenceProductionEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "scheduled_cleanup_worker blocked_claims_called_out must be a list."
             )
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "scheduled_cleanup_worker missing blocked claim callouts")
           )
  end

  test "JSON review hides internal blocked claim container guards" do
    review =
      complete_json_input()
      |> put_in(["scheduled_cleanup_worker", "blocked_claims_called_out"], "delivery_record")
      |> LocalPersistenceProductionEvidenceReview.json_review()

    evidence = review["evidence_by_gate"]["scheduled_cleanup_worker"]

    refute Map.has_key?(evidence, "blocked_claims_called_out_container_valid?")
    assert review["status"] == "open"
  end

  test "ready metadata must use the required evidence type for each gate" do
    input =
      complete_json_input()
      |> put_in(["on_device_restore_fixture", "evidence_type"], "cleanup_test")

    review = LocalPersistenceProductionEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "on_device_restore_fixture evidence_type must be :on_device_restore_fixture"
             )
           )
  end

  test "evidence artifact paths must be release-relative" do
    input =
      complete_json_input()
      |> put_in(["default_lifecycle_decision", "artifact_path"], "/tmp/persistence/decision.md")
      |> put_in(["schema_migration_policy", "artifact_path"], "../outside/schema.md")
      |> put_in(["scheduled_cleanup_worker", "artifact_path"], "file:///tmp/cleanup.md")
      |> put_in(["background_safe_writer", "artifact_path"], "https://example.invalid/writer.md")
      |> put_in(["on_device_restore_fixture", "artifact_path"], "~/restore")

    review = LocalPersistenceProductionEvidenceReview.review(input)

    assert review.status == :open

    for gate <- [
          :default_lifecycle_decision,
          :schema_migration_policy,
          :scheduled_cleanup_worker,
          :background_safe_writer,
          :on_device_restore_fixture
        ] do
      assert Enum.any?(
               review.missing,
               &String.contains?(&1, "#{gate} artifact_path must be a relative artifact path.")
             )
    end
  end

  test "evidence text fields must be strings and not need trimming" do
    input =
      complete_json_input()
      |> put_in(["default_lifecycle_decision", "artifact_path"], 123)
      |> put_in(["schema_migration_policy", "summary"], 456)
      |> put_in(["scheduled_cleanup_worker", "test_command"], 789)
      |> put_in(
        ["background_safe_writer", "artifact_path"],
        " artifacts/local-ble/run/persistence/writer.md"
      )
      |> put_in(["on_device_restore_fixture", "summary"], " restore evidence attached ")
      |> put_in(["release_artifact_evidence", "test_command"], " mix test persistence ")

    review = LocalPersistenceProductionEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "default_lifecycle_decision artifact_path must be a string.")
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "schema_migration_policy summary must be a string.")
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "scheduled_cleanup_worker test_command must be a string.")
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "background_safe_writer artifact_path must not have leading or trailing whitespace."
             )
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "on_device_restore_fixture summary must not have leading or trailing whitespace."
             )
           )

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "release_artifact_evidence test_command must not have leading or trailing whitespace."
             )
           )
  end

  test "ready metadata must call out gate-specific blocked claims" do
    input =
      complete_json_input()
      |> put_in(
        ["schema_migration_policy", "blocked_claims_called_out"],
        Enum.map(
          LocalPersistenceProductionEvidenceReview.required_blocked_claims(),
          &Atom.to_string/1
        )
      )

    review = LocalPersistenceProductionEvidenceReview.review(input)

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "schema_migration_policy missing gate-specific blocked claim callouts"
             )
           )
  end

  defp complete_json_input do
    gate_claims =
      Map.new(
        LocalPersistenceProductionEvidenceReview.review(%{}).production_lifecycle_plan.gates,
        &{&1.id, &1.blocked_claims}
      )

    Map.new(LocalPersistenceProductionEvidenceReview.required_gates(), fn gate ->
      {Atom.to_string(gate),
       %{
         "artifact_path" => "artifacts/local-ble/run/persistence/#{gate}.md",
         "summary" => "#{gate} evidence attached",
         "test_command" =>
           "mix test apps/mob_node/test/mob_node/ble/local_persistence_#{gate}_test.exs",
         "evidence_type" =>
           LocalPersistenceProductionEvidenceReview.required_evidence_types()
           |> Map.fetch!(gate)
           |> Atom.to_string(),
         "decision_outcome" => decision_outcome(gate),
         "blocked_claims_called_out" =>
           (LocalPersistenceProductionEvidenceReview.required_blocked_claims() ++
              Map.fetch!(gate_claims, gate))
           |> Enum.uniq()
           |> Enum.map(&Atom.to_string/1)
       }}
    end)
  end

  defp decision_outcome(:default_lifecycle_decision), do: "keep_memory_only_default"
  defp decision_outcome(_gate), do: nil
end
