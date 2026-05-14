defmodule Mix.Tasks.MeshxMobileLocalLifecycleHardwareReviewTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mix.Tasks.Meshx.Mobile.LocalLifecycle.HardwareReview
  alias MeshxMobileApp.BLE.LocalLifecycleHardwareEvidenceReview

  setup do
    Mix.Task.reenable("meshx.mobile.local_lifecycle.hardware_review")
    File.rm_rf!("tmp/local-lifecycle-hardware-review-test")
    :ok
  end

  test "prints an open review summary without input" do
    output =
      capture_io(fn ->
        HardwareReview.run([])
      end)

    assert output =~ "LOCAL_LIFECYCLE_HARDWARE_REVIEW status=open complete=false"
    assert output =~ "LIFECYCLE_HARDWARE_REVIEW missing"
    assert output =~ "gates 8"

    assert output =~
             "LIFECYCLE_HARDWARE_TEMPLATE command=mix meshx.mobile.local_lifecycle.hardware_review --template"
  end

  test "plain ready review does not print the template hint" do
    input_path = "tmp/local-lifecycle-hardware-review-test/input.json"
    File.mkdir_p!(Path.dirname(input_path))
    File.write!(input_path, JSON.encode!(complete_json_input()) <> "\n")

    output =
      capture_io(fn ->
        HardwareReview.run(["--input", input_path])
      end)

    assert output =~ "LOCAL_LIFECYCLE_HARDWARE_REVIEW status=ready complete=true"
    refute output =~ "LIFECYCLE_HARDWARE_TEMPLATE"
  end

  test "prints machine-readable JSON for missing evidence" do
    output =
      capture_io(fn ->
        HardwareReview.run(["--json"])
      end)

    assert {:ok, decoded} = JSON.decode(output)
    assert decoded["review_version"] == 1
    assert decoded["boundary"] == "mobile_ble_lifecycle_hardware_evidence_review"
    assert decoded["status"] == "open"
    assert decoded["lifecycle_hardware_evidence_complete?"] == false
  end

  test "reviews string-keyed JSON input and writes output artifact" do
    input_path = "tmp/local-lifecycle-hardware-review-test/input.json"
    output_path = "tmp/local-lifecycle-hardware-review-test/review.json"
    File.mkdir_p!(Path.dirname(input_path))
    File.write!(input_path, JSON.encode!(complete_json_input()) <> "\n")

    output =
      capture_io(fn ->
        HardwareReview.run(["--input", input_path, "--json", "--out", output_path])
      end)

    assert {:ok, decoded_output} = JSON.decode(output)
    assert decoded_output["status"] == "ready"
    assert decoded_output["lifecycle_hardware_evidence_complete?"] == true
    assert decoded_output["background_ble_claim_allowed?"] == false
    assert File.exists?(output_path)
    assert {:ok, decoded_file} = output_path |> File.read!() |> JSON.decode()
    assert decoded_file["missing"] == []
  end

  test "prints and writes an incomplete operator evidence template" do
    output_path = "tmp/local-lifecycle-hardware-review-test/template.json"

    output =
      capture_io(fn ->
        HardwareReview.run(["--template", "--out", output_path])
      end)

    assert {:ok, decoded_output} = JSON.decode(output)
    assert File.exists?(output_path)
    assert {:ok, decoded_file} = output_path |> File.read!() |> JSON.decode()
    assert decoded_file == decoded_output

    assert Map.keys(decoded_output) |> Enum.sort() ==
             LocalLifecycleHardwareEvidenceReview.required_gates()
             |> Enum.map(&Atom.to_string/1)
             |> Enum.sort()

    review = LocalLifecycleHardwareEvidenceReview.review(decoded_output)
    assert review.status == :open
    refute review.lifecycle_hardware_evidence_complete?
    refute review.background_ble_claim_allowed?
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
    gate_claims = LocalLifecycleHardwareEvidenceReview.required_gate_blocked_claims()

    Map.new(LocalLifecycleHardwareEvidenceReview.required_gates(), fn gate ->
      {Atom.to_string(gate),
       %{
         "artifact_path" => "artifacts/local-ble/run/lifecycle/#{gate}.md",
         "summary" => "#{gate} evidence attached",
         "test_command" => "mix test",
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
