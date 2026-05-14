defmodule Mix.Tasks.MeshxMobileLocalReadinessAuditTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mix.Tasks.Meshx.Mobile.LocalReadiness.Audit

  setup do
    Mix.Task.reenable("meshx.mobile.local_readiness.audit")
    File.rm_rf!("tmp/local-readiness-audit-test")
    :ok
  end

  test "prints readiness status when open items are allowed" do
    output =
      capture_io(fn ->
        Audit.run(["--allow-open"])
      end)

    assert output =~ "OPEN 10 blocked 3 partial 7 not_started 0"
    assert output =~ "BLOCKED full_message_resolution"
    assert output =~ "PARTIAL product_ux"
    assert output =~ "PARTIAL security_identity"
    assert output =~ "PARTIAL routing"
    assert output =~ "PARTIAL background_mobile_lifecycle"
    assert output =~ "PARTIAL ios_parity"
  end

  test "prints machine-readable readiness JSON when requested" do
    output =
      capture_io(fn ->
        Audit.run(["--allow-open", "--json"])
      end)

    assert {:ok, decoded} = JSON.decode(output)
    assert decoded["open_item_count"] == 10
    assert decoded["blocked_item_count"] == 3
    assert decoded["partial_item_count"] == 7
    assert decoded["not_started_item_count"] == 0

    assert Enum.any?(
             decoded["open_items"],
             &(&1["id"] == "full_message_resolution" and &1["status"] == "blocked")
           )

    assert Enum.any?(
             decoded["open_items"],
             &(&1["id"] == "ios_parity" and &1["status"] == "partial")
           )
  end

  test "writes machine-readable readiness JSON artifact when requested" do
    path = "tmp/local-readiness-audit-test/readiness.json"

    output =
      capture_io(fn ->
        Audit.run(["--allow-open", "--out", path])
      end)

    assert output =~ "OPEN 10 blocked 3 partial 7 not_started 0"
    assert File.exists?(path)
    assert {:ok, decoded} = path |> File.read!() |> JSON.decode()
    assert decoded["open_item_count"] == 10
    assert Enum.any?(decoded["open_items"], &(&1["id"] == "release_hardening"))
  end

  test "fails by default while project readiness items remain open" do
    assert_raise Mix.Error, ~r/local BLE mesh project readiness has 10 open items/, fn ->
      capture_io(fn ->
        Audit.run([])
      end)
    end
  end

  test "rejects unknown options" do
    assert_raise Mix.Error, ~r/unknown option/, fn ->
      capture_io(fn ->
        Audit.run(["--bad"])
      end)
    end
  end

  test "rejects missing artifact path" do
    assert_raise Mix.Error, ~r/missing path for --out/, fn ->
      capture_io(fn ->
        Audit.run(["--allow-open", "--out"])
      end)
    end
  end
end
