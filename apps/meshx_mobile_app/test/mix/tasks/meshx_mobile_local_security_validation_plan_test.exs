defmodule Mix.Tasks.MeshxMobileLocalSecurityValidationPlanTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mix.Tasks.Meshx.Mobile.LocalSecurity.ValidationPlan

  setup do
    Mix.Task.reenable("meshx.mobile.local_security.validation_plan")
    File.rm_rf!("tmp/local-security-validation-plan-test")
    :ok
  end

  test "prints a concise security validation plan summary" do
    output =
      capture_io(fn ->
        ValidationPlan.run([])
      end)

    assert output =~
             "LOCAL_SECURITY_VALIDATION_PLAN authenticated_local_ble_security_validation_plan"

    assert output =~ "current_mode=unsigned_local_ble_observations"
    assert output =~ "trusted_message_allowed=false"
    assert output =~ "trusted_delivery_allowed=false"
    assert output =~ "SECURITY_VALIDATION_GATES blocked=8 total=8"
    assert output =~ "authenticated_peer_allowed=false"

    assert output =~
             "SECURITY_VALIDATION_REQUIRED gates=peer_key_enrollment,authorship_fixture_matrix,replay_state_lifecycle,trust_policy_lifecycle,canonical_replay_integration,beacon_ref_authentication_integration,release_artifact_evidence,negative_claim_review"

    assert output =~ "Persistent or supplied key enrollment decision"
  end

  test "prints machine-readable JSON" do
    output =
      capture_io(fn ->
        ValidationPlan.run(["--json"])
      end)

    assert {:ok, decoded} = JSON.decode(output)
    assert decoded["plan_version"] == 1
    assert decoded["boundary"] == "authenticated_local_ble_security_validation_plan"
    assert decoded["current_mode"] == "unsigned_local_ble_observations"
    assert decoded["trusted_message_claim_allowed?"] == false
    assert decoded["blocked_gate_count"] == 8
    assert Enum.any?(decoded["gates"], &(&1["id"] == "beacon_ref_authentication_integration"))
  end

  test "writes machine-readable JSON artifact" do
    path = "tmp/local-security-validation-plan-test/plan.json"

    output =
      capture_io(fn ->
        ValidationPlan.run(["--json", "--out", path])
      end)

    assert {:ok, decoded_output} = JSON.decode(output)
    assert decoded_output["boundary"] == "authenticated_local_ble_security_validation_plan"
    assert File.exists?(path)
    assert {:ok, decoded_file} = path |> File.read!() |> JSON.decode()
    assert decoded_file["trusted_delivery_claim_allowed?"] == false
  end

  test "rejects unknown options and missing output path" do
    assert_raise Mix.Error, ~r/unknown option/, fn ->
      capture_io(fn -> ValidationPlan.run(["--bad"]) end)
    end

    assert_raise Mix.Error, ~r/missing path for --out/, fn ->
      capture_io(fn -> ValidationPlan.run(["--out"]) end)
    end
  end
end
