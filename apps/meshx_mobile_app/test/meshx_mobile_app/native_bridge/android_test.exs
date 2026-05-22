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

  test "calls fail closed when the JNI NIF is absent (host environment)" do
    # No native `:mob_ble_nif` library on the host VM, so every delegated call raises
    # rather than silently succeeding — a misconfigured runtime that
    # selected the Android bridge without the NIF fails loudly.
    refute match?({:module, :mob_ble_nif}, Code.ensure_loaded(:mob_ble_nif))

    assert_raise UndefinedFunctionError, fn -> Android.start_scan(self()) end
    assert_raise UndefinedFunctionError, fn -> Android.start_advertising(self(), "meshx-mob") end
    assert_raise UndefinedFunctionError, fn -> Android.stop(self()) end
    assert_raise UndefinedFunctionError, fn -> Android.send_to_peer(self(), "peer", "ping") end
  end
end
