defmodule Mix.Tasks.Mob.NodeLocalKnownGoodTransportReviewTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mix.Tasks.Mob.Node.LocalKnownGoodTransport.Review
  alias Mob.Node.BLE.LocalKnownGoodTransportEvidenceReview

  setup do
    Mix.Task.reenable("mob.node.local_known_good_transport.review")
    File.rm_rf!("tmp/local-known-good-transport-review-test")
    :ok
  end

  test "prints an open review summary without input" do
    output =
      capture_io(fn ->
        Review.run([])
      end)

    assert output =~ "LOCAL_KNOWN_GOOD_TRANSPORT_REVIEW status=open complete=false"
    assert output =~ "KNOWN_GOOD_TRANSPORT_REVIEW missing"
    assert output =~ "gates 6"

    assert output =~
             "KNOWN_GOOD_TRANSPORT_TEMPLATE command=mix mob.node.local_known_good_transport.review --template"
  end

  test "plain ready review does not print the template hint" do
    input_path = "tmp/local-known-good-transport-review-test/input.json"
    File.mkdir_p!(Path.dirname(input_path))
    File.write!(input_path, JSON.encode!(complete_json_input()) <> "\n")

    output =
      capture_io(fn ->
        Review.run(["--input", input_path])
      end)

    assert output =~ "LOCAL_KNOWN_GOOD_TRANSPORT_REVIEW status=ready complete=true"
    refute output =~ "KNOWN_GOOD_TRANSPORT_TEMPLATE"
  end

  test "prints machine-readable JSON for missing evidence" do
    output =
      capture_io(fn ->
        Review.run(["--json"])
      end)

    assert {:ok, decoded} = JSON.decode(output)
    assert decoded["review_version"] == 1
    assert decoded["boundary"] == "known_good_transport_evidence_review"
    assert decoded["status"] == "open"
    assert decoded["known_good_transport_evidence_complete?"] == false
  end

  test "reviews string-keyed JSON input and writes output artifact" do
    input_path = "tmp/local-known-good-transport-review-test/input.json"
    output_path = "tmp/local-known-good-transport-review-test/review.json"
    File.mkdir_p!(Path.dirname(input_path))
    File.write!(input_path, JSON.encode!(complete_json_input()) <> "\n")

    output =
      capture_io(fn ->
        Review.run(["--input", input_path, "--json", "--out", output_path])
      end)

    assert {:ok, decoded_output} = JSON.decode(output)
    assert decoded_output["status"] == "ready"
    assert decoded_output["known_good_transport_evidence_complete?"] == true
    assert decoded_output["known_good_transport_claim_allowed?"] == false
    assert File.exists?(output_path)
  end

  test "prints and writes an incomplete operator evidence template" do
    output_path = "tmp/local-known-good-transport-review-test/template.json"

    output =
      capture_io(fn ->
        Review.run(["--template", "--out", output_path])
      end)

    assert {:ok, decoded_output} = JSON.decode(output)
    assert File.exists?(output_path)
    assert {:ok, decoded_file} = output_path |> File.read!() |> JSON.decode()
    assert decoded_file == decoded_output

    assert Map.keys(decoded_output) |> Enum.sort() ==
             LocalKnownGoodTransportEvidenceReview.required_gates()
             |> Enum.map(&Atom.to_string/1)
             |> Enum.sort()

    review = LocalKnownGoodTransportEvidenceReview.review(decoded_output)
    assert review.status == :open
    refute review.known_good_transport_evidence_complete?
    refute review.known_good_transport_claim_allowed?
  end

  test "rejects unknown options and missing paths" do
    assert_raise Mix.Error, ~r/unknown option/, fn ->
      capture_io(fn -> Review.run(["--bad"]) end)
    end

    assert_raise Mix.Error, ~r/missing path for --input/, fn ->
      capture_io(fn -> Review.run(["--input"]) end)
    end

    assert_raise Mix.Error, ~r/missing path for --out/, fn ->
      capture_io(fn -> Review.run(["--out"]) end)
    end

    assert_raise Mix.Error, ~r/--template cannot be combined with --input/, fn ->
      capture_io(fn -> Review.run(["--template", "--input", "tmp/input.json"]) end)
    end
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
