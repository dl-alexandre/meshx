defmodule Mix.Tasks.MeshxMobileLocalInboxUxReviewTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mix.Tasks.Meshx.Mobile.LocalInbox.UxReview
  alias MeshxMobileApp.BLE.LocalInboxUxEvidenceReview

  setup do
    Mix.Task.reenable("meshx.mobile.local_inbox.ux_review")
    File.rm_rf!("tmp/local-inbox-ux-review-test")
    :ok
  end

  test "prints an open review summary without input" do
    output =
      capture_io(fn ->
        UxReview.run([])
      end)

    assert output =~ "LOCAL_INBOX_UX_REVIEW status=open complete=false"
    assert output =~ "states 4 interactions 4"
    assert output =~ "LOCAL_INBOX_UX_COVERAGE"
    assert output =~ "targets=0"
    assert output =~ "all_states=false"
    assert output =~ "LOCAL_INBOX_UX_COPY_REVIEW"
    assert output =~ "warnings_captured=false"
    assert output =~ "control_summaries_captured=false"
    assert output =~ "state_blocked_claim_copy_captured=false"
    assert output =~ "detail_panel_copy_captured=false"

    assert output =~
             "LOCAL_INBOX_UX_TEMPLATE command=mix meshx.mobile.local_inbox.ux_review --template"
  end

  test "plain ready review does not print the template hint" do
    input_path = "tmp/local-inbox-ux-review-test/input.json"
    File.mkdir_p!(Path.dirname(input_path))
    File.write!(input_path, JSON.encode!(complete_json_input()) <> "\n")

    output =
      capture_io(fn ->
        UxReview.run(["--input", input_path])
      end)

    assert output =~ "LOCAL_INBOX_UX_REVIEW status=ready complete=true"
    assert output =~ "LOCAL_INBOX_UX_COVERAGE"
    assert output =~ "targets=1"
    assert output =~ "state_items=4"
    assert output =~ "interaction_items=4"
    assert output =~ "selected_detail_items=4"
    assert output =~ "all_states=true"
    assert output =~ "all_interactions=true"
    assert output =~ "all_selected_details=true"
    assert output =~ "copy_reviewed=true"
    assert output =~ "density_reviewed=true"
    assert output =~ "LOCAL_INBOX_UX_COPY_REVIEW"
    assert output =~ "warnings_captured=true"
    assert output =~ "control_summaries_captured=true"
    assert output =~ "state_blocked_claim_copy_captured=true"
    assert output =~ "detail_panel_copy_captured=true"
    assert output =~ "blocked_claims=4"
    refute output =~ "LOCAL_INBOX_UX_TEMPLATE"
  end

  test "prints machine-readable JSON for missing evidence" do
    output =
      capture_io(fn ->
        UxReview.run(["--json"])
      end)

    assert {:ok, decoded} = JSON.decode(output)
    assert decoded["review_version"] == 1
    assert decoded["boundary"] == "nearby_messages_on_device_ux_evidence"
    assert decoded["status"] == "open"
    assert decoded["on_device_ux_evidence_complete?"] == false
  end

  test "reviews string-keyed JSON input and writes output artifact" do
    input_path = "tmp/local-inbox-ux-review-test/input.json"
    output_path = "tmp/local-inbox-ux-review-test/review.json"
    File.mkdir_p!(Path.dirname(input_path))
    File.write!(input_path, JSON.encode!(complete_json_input()) <> "\n")

    output =
      capture_io(fn ->
        UxReview.run(["--input", input_path, "--json", "--out", output_path])
      end)

    assert {:ok, decoded_output} = JSON.decode(output)
    assert decoded_output["status"] == "ready"
    assert decoded_output["on_device_ux_evidence_complete?"] == true
    assert decoded_output["delivery_claim_allowed?"] == false
    assert decoded_output["coverage_summary"]["all_target_devices_have_state_coverage?"] == true

    assert decoded_output["coverage_summary"][
             "all_target_devices_have_selected_detail_coverage?"
           ] == true

    assert File.exists?(output_path)
    assert {:ok, decoded_file} = output_path |> File.read!() |> JSON.decode()
    assert decoded_file["missing"] == []
  end

  test "written JSON artifact does not expose internal validation flags" do
    input_path = "tmp/local-inbox-ux-review-test/input.json"
    output_path = "tmp/local-inbox-ux-review-test/review.json"
    File.mkdir_p!(Path.dirname(input_path))
    File.write!(input_path, JSON.encode!(complete_json_input()) <> "\n")

    capture_io(fn ->
      UxReview.run(["--input", input_path, "--json", "--out", output_path])
    end)

    assert {:ok, decoded_file} = output_path |> File.read!() |> JSON.decode()

    refute Map.has_key?(
             decoded_file["copy_review"],
             "target_device_ids_reviewed_container_valid?"
           )

    refute Map.has_key?(decoded_file["copy_review"], "target_device_ids_reviewed_present?")
    refute Map.has_key?(decoded_file["copy_review"], "blocked_claims_called_out_container_valid?")
    refute Map.has_key?(decoded_file["copy_review"], "blocked_claims_called_out_present?")
    refute Map.has_key?(decoded_file["copy_review"], "warning_text_captured_present?")
    refute Map.has_key?(decoded_file["copy_review"], "control_summaries_captured_present?")
    refute Map.has_key?(decoded_file["copy_review"], "state_blocked_claim_copy_captured_present?")
    refute Map.has_key?(decoded_file["copy_review"], "detail_panel_copy_captured_present?")

    refute Map.has_key?(
             decoded_file["visual_density_review"],
             "target_device_ids_reviewed_container_valid?"
           )

    refute Map.has_key?(
             decoded_file["visual_density_review"],
             "target_device_ids_reviewed_present?"
           )

    refute Map.has_key?(decoded_file["visual_density_review"], "row_truncation_reviewed_present?")
    refute Map.has_key?(decoded_file["visual_density_review"], "wrapping_reviewed_present?")
    refute Map.has_key?(decoded_file["visual_density_review"], "tap_targets_reviewed_present?")

    refute Map.has_key?(
             decoded_file["visual_density_review"],
             "detail_readability_reviewed_present?"
           )

    refute Map.has_key?(
             decoded_file["visual_density_review"],
             "densest_fixture_captured_present?"
           )
  end

  test "JSON input with malformed evidence shape fails closed through the task" do
    input_path = "tmp/local-inbox-ux-review-test/input.json"
    output_path = "tmp/local-inbox-ux-review-test/review.json"
    File.mkdir_p!(Path.dirname(input_path))
    File.write!(input_path, JSON.encode!("not-a-map") <> "\n")

    output =
      capture_io(fn ->
        UxReview.run(["--input", input_path, "--json", "--out", output_path])
      end)

    assert {:ok, decoded_output} = JSON.decode(output)
    assert decoded_output["status"] == "open"
    assert decoded_output["on_device_ux_evidence_complete?"] == false

    assert Enum.any?(
             decoded_output["missing"],
             &String.contains?(&1, "Missing at least one target device")
           )

    assert {:ok, decoded_file} = output_path |> File.read!() |> JSON.decode()
    assert decoded_file == decoded_output
  end

  test "prints and writes an incomplete operator evidence template" do
    output_path = "tmp/local-inbox-ux-review-test/template.json"

    output =
      capture_io(fn ->
        UxReview.run(["--template", "--out", output_path])
      end)

    assert {:ok, decoded_output} = JSON.decode(output)
    assert File.exists?(output_path)
    assert {:ok, decoded_file} = output_path |> File.read!() |> JSON.decode()
    assert decoded_file == decoded_output

    assert Enum.map(decoded_output["state_evidence"], & &1["state"]) ==
             Enum.map(LocalInboxUxEvidenceReview.required_states(), &Atom.to_string/1)

    assert Enum.map(decoded_output["selected_detail_evidence"], & &1["state"]) ==
             Enum.map(LocalInboxUxEvidenceReview.required_states(), &Atom.to_string/1)

    assert Enum.all?(decoded_output["interaction_evidence"], &Map.has_key?(&1, "evidence_kind"))

    assert Enum.all?(
             decoded_output["selected_detail_evidence"],
             &Map.has_key?(&1, "evidence_kind")
           )

    assert decoded_output["copy_review"]["control_summaries_captured"] == false
    assert decoded_output["copy_review"]["state_blocked_claim_copy_captured"] == false
    assert Map.has_key?(decoded_output["copy_review"], "evidence_kind")
    assert Map.has_key?(decoded_output["visual_density_review"], "evidence_kind")
    assert Map.has_key?(decoded_output["visual_density_review"], "densest_fixture_artifact_path")
    assert Map.has_key?(decoded_output["visual_density_review"], "densest_fixture_evidence_kind")

    review = LocalInboxUxEvidenceReview.review(decoded_output)
    assert review.status == :open
    refute review.on_device_ux_evidence_complete?
    assert Enum.any?(review.missing, &String.contains?(&1, "control summaries"))
    assert Enum.any?(review.missing, &String.contains?(&1, "per-state blocked-claim copy"))
    assert Enum.any?(review.missing, &String.contains?(&1, "Selected detail evidence"))
  end

  test "rejects unknown options and missing paths" do
    assert_raise Mix.Error, ~r/unknown option/, fn ->
      capture_io(fn -> UxReview.run(["--bad"]) end)
    end

    assert_raise Mix.Error, ~r/missing path for --input/, fn ->
      capture_io(fn -> UxReview.run(["--input"]) end)
    end

    assert_raise Mix.Error, ~r/missing path for --out/, fn ->
      capture_io(fn -> UxReview.run(["--out"]) end)
    end

    assert_raise Mix.Error, ~r/--template cannot be combined with --input/, fn ->
      capture_io(fn -> UxReview.run(["--template", "--input", "tmp/input.json"]) end)
    end
  end

  defp complete_json_input do
    %{
      "target_devices" => [
        %{
          "device_id" => "sm-t390",
          "device_model" => "SM-T390",
          "os_or_api_version" => "Android API 28",
          "screen_size_class" => "small_tablet",
          "app_build_id" => "meshx-local-debug-2026-05-13",
          "evidence_path" => "artifacts/local-ble/run/ux/sm-t390/"
        }
      ],
      "state_evidence" =>
        Enum.map(LocalInboxUxEvidenceReview.required_states(), fn state ->
          %{
            "state" => Atom.to_string(state),
            "target_device_id" => "sm-t390",
            "evidence_kind" => "screenshot",
            "artifact_path" => "artifacts/local-ble/run/ux/#{state}.png",
            "notes" => "#{state} row visible"
          }
        end),
      "interaction_evidence" =>
        Enum.map(LocalInboxUxEvidenceReview.required_interactions(), fn interaction ->
          %{
            "interaction" => Atom.to_string(interaction),
            "target_device_id" => "sm-t390",
            "evidence_kind" => "screenshot",
            "artifact_path" => "artifacts/local-ble/run/ux/#{interaction}.png",
            "notes" => "#{interaction} usable"
          }
        end),
      "selected_detail_evidence" =>
        Enum.map(LocalInboxUxEvidenceReview.required_states(), fn state ->
          %{
            "state" => Atom.to_string(state),
            "target_device_id" => "sm-t390",
            "evidence_kind" => "screenshot",
            "artifact_path" => "artifacts/local-ble/run/ux/selected-detail-#{state}.png",
            "limitation_copy" => "#{state} detail is a local BLE observation",
            "next_action_copy" => "#{state} next action is visible",
            "blocked_claim_copy" => "#{state} detail does not claim delivery or trust",
            "notes" => "#{state} selected detail limitation and next-action copy visible"
          }
        end),
      "copy_review" => %{
        "review_path" => "artifacts/local-ble/run/ux/copy-review.md",
        "evidence_kind" => "operator_note",
        "target_device_ids_reviewed" => ["sm-t390"],
        "allowed_wording" => LocalInboxUxEvidenceReview.allowed_wording(),
        "blocked_claims_called_out" =>
          Enum.map(LocalInboxUxEvidenceReview.required_blocked_claims(), &Atom.to_string/1),
        "warning_text_captured" => true,
        "control_summaries_captured" => true,
        "state_blocked_claim_copy_captured" => true,
        "detail_panel_copy_captured" => true
      },
      "visual_density_review" => %{
        "artifact_path" => "artifacts/local-ble/run/ux/density.md",
        "evidence_kind" => "operator_note",
        "densest_fixture_artifact_path" => "artifacts/local-ble/run/ux/densest-fixture.png",
        "densest_fixture_evidence_kind" => "screenshot",
        "target_device_ids_reviewed" => ["sm-t390"],
        "row_truncation_reviewed" => true,
        "wrapping_reviewed" => true,
        "tap_targets_reviewed" => true,
        "detail_readability_reviewed" => true,
        "densest_fixture_captured" => true
      }
    }
  end
end
