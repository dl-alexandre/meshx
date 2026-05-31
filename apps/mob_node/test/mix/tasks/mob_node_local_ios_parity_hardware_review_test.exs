defmodule Mix.Tasks.Mob.NodeLocalIOSParityHardwareReviewTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mix.Tasks.Mob.Node.LocalIosParity.HardwareReview
  alias Mob.Node.BLE.LocalIOSParityHardwareEvidenceReview

  setup do
    Mix.Task.reenable("mob.node.local_ios_parity.hardware_review")
    File.rm_rf!("tmp/local-ios-parity-hardware-review-test")
    :ok
  end

  test "prints an open review summary without input" do
    output =
      capture_io(fn ->
        HardwareReview.run([])
      end)

    assert output =~ "LOCAL_IOS_PARITY_HARDWARE_REVIEW status=open complete=false"
    assert output =~ "IOS_PARITY_HARDWARE_REVIEW missing"
    assert output =~ "gates 8"

    assert output =~
             "IOS_PARITY_HARDWARE_TEMPLATE command=mix mob.node.local_ios_parity.hardware_review --template"
  end

  test "plain ready review does not print the template hint" do
    input_path = "tmp/local-ios-parity-hardware-review-test/input.json"
    File.mkdir_p!(Path.dirname(input_path))
    File.write!(input_path, JSON.encode!(complete_json_input()) <> "\n")

    output =
      capture_io(fn ->
        HardwareReview.run(["--input", input_path])
      end)

    assert output =~ "LOCAL_IOS_PARITY_HARDWARE_REVIEW status=ready complete=true"
    refute output =~ "IOS_PARITY_HARDWARE_TEMPLATE"
  end

  test "prints machine-readable JSON for missing evidence" do
    output =
      capture_io(fn ->
        HardwareReview.run(["--json"])
      end)

    assert {:ok, decoded} = JSON.decode(output)
    assert decoded["review_version"] == 1
    assert decoded["boundary"] == "ios_advert_only_hardware_evidence_review"
    assert decoded["status"] == "open"
    assert decoded["ios_hardware_evidence_complete?"] == false
  end

  test "reviews string-keyed JSON input and writes output artifact" do
    input_path = "tmp/local-ios-parity-hardware-review-test/input.json"
    output_path = "tmp/local-ios-parity-hardware-review-test/review.json"
    File.mkdir_p!(Path.dirname(input_path))
    File.write!(input_path, JSON.encode!(complete_json_input()) <> "\n")

    output =
      capture_io(fn ->
        HardwareReview.run(["--input", input_path, "--json", "--out", output_path])
      end)

    assert {:ok, decoded_output} = JSON.decode(output)
    assert decoded_output["status"] == "ready"
    assert decoded_output["ios_hardware_evidence_complete?"] == true
    assert decoded_output["ios_parity_claim_allowed?"] == false
    assert File.exists?(output_path)
    assert {:ok, decoded_file} = output_path |> File.read!() |> JSON.decode()
    assert decoded_file["missing"] == []
  end

  test "prints and writes an incomplete operator evidence template" do
    output_path = "tmp/local-ios-parity-hardware-review-test/template.json"

    output =
      capture_io(fn ->
        HardwareReview.run(["--template", "--out", output_path])
      end)

    assert {:ok, decoded_output} = JSON.decode(output)
    assert File.exists?(output_path)
    assert {:ok, decoded_file} = output_path |> File.read!() |> JSON.decode()
    assert decoded_file == decoded_output

    assert Map.keys(decoded_output) |> Enum.sort() ==
             LocalIOSParityHardwareEvidenceReview.required_gates()
             |> Enum.map(&Atom.to_string/1)
             |> Enum.sort()

    review = LocalIOSParityHardwareEvidenceReview.review(decoded_output)
    assert review.status == :open
    refute review.ios_hardware_evidence_complete?
    refute review.ios_parity_claim_allowed?
  end

  test "rejects unknown options and missing paths" do
    assert_raise Mix.Error, ~r/unknown option/, fn ->
      capture_io(fn -> HardwareReview.run(["--bad"]) end)
    end

    assert_raise Mix.Error, ~r/missing path for --input/, fn ->
      capture_io(fn -> HardwareReview.run(["--input"]) end)
    end

    assert_raise Mix.Error, ~r/missing path for --out/, fn ->
      capture_io(fn -> HardwareReview.run(["--out"]) end)
    end

    assert_raise Mix.Error, ~r/--template cannot be combined with --input/, fn ->
      capture_io(fn -> HardwareReview.run(["--template", "--input", "tmp/input.json"]) end)
    end
  end

  defp complete_json_input do
    gate_claims = LocalIOSParityHardwareEvidenceReview.required_gate_blocked_claims()

    Map.new(LocalIOSParityHardwareEvidenceReview.required_gates(), fn gate ->
      {Atom.to_string(gate),
       %{
         "artifact_path" => "artifacts/local-ble/run/ios/#{gate}.md",
         "summary" => "#{gate} evidence attached",
         "test_command" => "mix test",
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
