defmodule Mix.Tasks.Mob.NodeLocalPersistenceProductionReviewTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mix.Tasks.Mob.Node.LocalPersistence.ProductionReview
  alias Mob.Node.BLE.LocalPersistenceProductionEvidenceReview

  setup do
    Mix.Task.reenable("mob.node.local_persistence.production_review")
    File.rm_rf!("tmp/local-persistence-production-review-test")
    :ok
  end

  test "prints an open review summary without input" do
    output =
      capture_io(fn ->
        ProductionReview.run([])
      end)

    assert output =~ "LOCAL_PERSISTENCE_PRODUCTION_REVIEW status=open complete=false"
    assert output =~ "PERSISTENCE_PRODUCTION_REVIEW missing"
    assert output =~ "gates 6"

    assert output =~
             "PERSISTENCE_PRODUCTION_TEMPLATE command=mix mob.node.local_persistence.production_review --template"
  end

  test "plain ready review does not print the template hint" do
    input_path = "tmp/local-persistence-production-review-test/input.json"
    File.mkdir_p!(Path.dirname(input_path))
    File.write!(input_path, JSON.encode!(complete_json_input()) <> "\n")

    output =
      capture_io(fn ->
        ProductionReview.run(["--input", input_path])
      end)

    assert output =~ "LOCAL_PERSISTENCE_PRODUCTION_REVIEW status=ready complete=true"
    refute output =~ "PERSISTENCE_PRODUCTION_TEMPLATE"
  end

  test "prints machine-readable JSON for missing evidence" do
    output =
      capture_io(fn ->
        ProductionReview.run(["--json"])
      end)

    assert {:ok, decoded} = JSON.decode(output)
    assert decoded["review_version"] == 1
    assert decoded["boundary"] == "production_default_persistence_evidence_review"
    assert decoded["status"] == "open"
    assert decoded["production_persistence_evidence_complete?"] == false
  end

  test "reviews string-keyed JSON input and writes output artifact" do
    input_path = "tmp/local-persistence-production-review-test/input.json"
    output_path = "tmp/local-persistence-production-review-test/review.json"
    File.mkdir_p!(Path.dirname(input_path))
    File.write!(input_path, JSON.encode!(complete_json_input()) <> "\n")

    output =
      capture_io(fn ->
        ProductionReview.run(["--input", input_path, "--json", "--out", output_path])
      end)

    assert {:ok, decoded_output} = JSON.decode(output)
    assert decoded_output["status"] == "ready"
    assert decoded_output["production_persistence_evidence_complete?"] == true
    assert decoded_output["production_default_persistence_allowed?"] == false
    assert File.exists?(output_path)
    assert {:ok, decoded_file} = output_path |> File.read!() |> JSON.decode()
    assert decoded_file["missing"] == []
  end

  test "prints and writes an incomplete operator evidence template" do
    output_path = "tmp/local-persistence-production-review-test/template.json"

    output =
      capture_io(fn ->
        ProductionReview.run(["--template", "--out", output_path])
      end)

    assert {:ok, decoded_output} = JSON.decode(output)
    assert File.exists?(output_path)
    assert {:ok, decoded_file} = output_path |> File.read!() |> JSON.decode()
    assert decoded_file == decoded_output

    assert Map.keys(decoded_output) |> Enum.sort() ==
             LocalPersistenceProductionEvidenceReview.required_gates()
             |> Enum.map(&Atom.to_string/1)
             |> Enum.sort()

    assert decoded_output["default_lifecycle_decision"]["decision_outcome"] == ""

    review = LocalPersistenceProductionEvidenceReview.review(decoded_output)
    assert review.status == :open
    refute review.production_persistence_evidence_complete?
  end

  test "rejects unknown options and missing paths" do
    assert_raise Mix.Error, ~r/unknown option/, fn ->
      capture_io(fn -> ProductionReview.run(["--bad"]) end)
    end

    assert_raise Mix.Error, ~r/missing path for --input/, fn ->
      capture_io(fn -> ProductionReview.run(["--input"]) end)
    end

    assert_raise Mix.Error, ~r/missing path for --out/, fn ->
      capture_io(fn -> ProductionReview.run(["--out"]) end)
    end

    assert_raise Mix.Error, ~r/--template cannot be combined with --input/, fn ->
      capture_io(fn -> ProductionReview.run(["--template", "--input", "tmp/input.json"]) end)
    end
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
         "test_command" => "mix test",
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
