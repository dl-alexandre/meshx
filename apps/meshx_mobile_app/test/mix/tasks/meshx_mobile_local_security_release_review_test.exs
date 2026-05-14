defmodule Mix.Tasks.MeshxMobileLocalSecurityReleaseReviewTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mix.Tasks.Meshx.Mobile.LocalSecurity.ReleaseReview
  alias MeshxMobileApp.BLE.LocalSecurityReleaseEvidenceReview

  setup do
    Mix.Task.reenable("meshx.mobile.local_security.release_review")
    File.rm_rf!("tmp/local-security-release-review-test")
    :ok
  end

  test "prints an open review summary without input" do
    output =
      capture_io(fn ->
        ReleaseReview.run([])
      end)

    assert output =~ "LOCAL_SECURITY_RELEASE_REVIEW status=open complete=false"
    assert output =~ "SECURITY_RELEASE_REVIEW missing"

    assert output =~
             "SECURITY_RELEASE_TEMPLATE command=mix meshx.mobile.local_security.release_review --template"
  end

  test "plain ready review does not print the template hint" do
    input_path = "tmp/local-security-release-review-test/input.json"
    File.mkdir_p!(Path.dirname(input_path))
    File.write!(input_path, JSON.encode!(complete_json_input()) <> "\n")

    output =
      capture_io(fn ->
        ReleaseReview.run(["--input", input_path])
      end)

    assert output =~ "LOCAL_SECURITY_RELEASE_REVIEW status=ready complete=true"
    refute output =~ "SECURITY_RELEASE_TEMPLATE"
  end

  test "prints machine-readable JSON for missing evidence" do
    output =
      capture_io(fn ->
        ReleaseReview.run(["--json"])
      end)

    assert {:ok, decoded} = JSON.decode(output)
    assert decoded["review_version"] == 1
    assert decoded["boundary"] == "local_security_release_evidence_review"
    assert decoded["status"] == "open"
    assert decoded["security_release_evidence_complete?"] == false
  end

  test "reviews string-keyed JSON input and writes output artifact" do
    input_path = "tmp/local-security-release-review-test/input.json"
    output_path = "tmp/local-security-release-review-test/review.json"
    File.mkdir_p!(Path.dirname(input_path))
    File.write!(input_path, JSON.encode!(complete_json_input()) <> "\n")

    output =
      capture_io(fn ->
        ReleaseReview.run(["--input", input_path, "--json", "--out", output_path])
      end)

    assert {:ok, decoded_output} = JSON.decode(output)
    assert decoded_output["status"] == "ready"
    assert decoded_output["security_release_evidence_complete?"] == true
    assert decoded_output["trusted_delivery_claim_allowed?"] == false
    assert decoded_output["missing"] == []
    assert File.exists?(output_path)
  end

  test "prints and writes an incomplete operator evidence template" do
    output_path = "tmp/local-security-release-review-test/template.json"

    output =
      capture_io(fn ->
        ReleaseReview.run(["--template", "--out", output_path])
      end)

    assert {:ok, decoded_output} = JSON.decode(output)
    assert File.exists?(output_path)
    assert {:ok, decoded_file} = output_path |> File.read!() |> JSON.decode()
    assert decoded_file == decoded_output

    [attachment] = decoded_output["security_attachments"]

    assert attachment["plan_gate_ids"] ==
             Enum.map(
               LocalSecurityReleaseEvidenceReview.required_plan_gate_ids(),
               &Atom.to_string/1
             )

    review = LocalSecurityReleaseEvidenceReview.review(decoded_output)
    assert review.status == :open
    refute review.security_release_evidence_complete?
  end

  test "rejects unknown options and missing paths" do
    assert_raise Mix.Error, ~r/unknown option/, fn ->
      capture_io(fn -> ReleaseReview.run(["--bad"]) end)
    end

    assert_raise Mix.Error, ~r/missing path for --input/, fn ->
      capture_io(fn -> ReleaseReview.run(["--input"]) end)
    end

    assert_raise Mix.Error, ~r/missing path for --out/, fn ->
      capture_io(fn -> ReleaseReview.run(["--out"]) end)
    end

    assert_raise Mix.Error, ~r/--template cannot be combined with --input/, fn ->
      capture_io(fn -> ReleaseReview.run(["--template", "--input", "tmp/input.json"]) end)
    end
  end

  defp complete_json_input do
    %{
      "readiness_manifest_path" => "tmp/local-readiness.json",
      "release_manifest_path" => "tmp/local-release.json",
      "security_manifest_path" => "tmp/local-security-evidence.json",
      "security_attachments" => [
        %{
          "artifact_id" => "security-fixture-audit",
          "path" => "tmp/local-security-evidence.json",
          "source" => "LocalSecurityFixtureAudit and LocalSecurityAcceptance",
          "plan_gate_ids" =>
            Enum.map(
              LocalSecurityReleaseEvidenceReview.required_plan_gate_ids(),
              &Atom.to_string/1
            ),
          "evidence_types_by_gate" =>
            LocalSecurityReleaseEvidenceReview.required_evidence_types()
            |> Map.new(fn {gate_id, evidence_type} ->
              {Atom.to_string(gate_id), Atom.to_string(evidence_type)}
            end),
          "blocked_claims_called_out" => Enum.map(complete_blocked_claims(), &Atom.to_string/1),
          "operator_reviewed?" => true
        }
      ]
    }
  end

  defp complete_blocked_claims do
    gate_claims =
      LocalSecurityReleaseEvidenceReview.required_gate_blocked_claims()
      |> Map.values()
      |> List.flatten()

    (LocalSecurityReleaseEvidenceReview.required_blocked_claims() ++ gate_claims)
    |> Enum.uniq()
  end
end
