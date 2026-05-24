defmodule MeshxMobileApp.NativeBridge.AndroidTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.Adapter
  alias MeshxMobileApp.NativeBridge.Android

  # The Android bridge delegates straight into `:mob_ble_nif`, the
  # JNI-backed NIF that only exists inside the Mob Android runtime. Host
  # tests therefore can't exercise the calls — but they can pin the
  # contract: the module must satisfy the `BLE.Adapter` behaviour with
  # the exact surface the runtime selects it for.

  test "declares the BLE.Adapter behaviour" do
    behaviours =
      Android.module_info(:attributes)
      |> Keyword.get_values(:behaviour)
      |> List.flatten()

    assert Adapter in behaviours
  end

  test "exports every BLE.Adapter callback at the right arity" do
    # `function_exported?/3` does not auto-load — make sure the module is
    # resident before probing it, otherwise an async run order can race.
    {:module, Android} = Code.ensure_loaded(Android)

    for {fun, arity} <- [start_scan: 1, start_advertising: 2, stop: 1, send_to_peer: 3] do
      assert function_exported?(Android, fun, arity),
             "Android bridge is missing #{fun}/#{arity}"
    end
  end

  test "host stub calls fail closed when native BLE is unavailable" do
    # `mob_ble` now ships the Erlang-facing :mob_ble_nif module in host tests.
    # Without the Android JNI runtime, the stub must still fail closed.
    assert {:module, :mob_ble_nif} = Code.ensure_loaded(:mob_ble_nif)

    assert {:error, :native_not_available} = Android.start_scan(self())
    assert {:error, :native_not_available} = Android.start_advertising(self(), "meshx-mob")
    assert {:error, :native_not_available} = Android.stop(self())
    assert {:error, :native_not_available} = Android.send_to_peer(self(), "peer", "ping")
  end
end
