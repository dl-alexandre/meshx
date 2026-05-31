defmodule Mob.Node.BLE.ErrorTest do
  use ExUnit.Case, async: true

  alias Mob.Node.BLE.Error

  test "taxonomy is closed and stable" do
    assert Error.kinds() == [
             :bluetooth_off,
             :unauthorized,
             :peripheral_unsupported,
             :advertise_failed,
             :scan_failed,
             :gatt_error,
             :timeout,
             :not_connected,
             :unknown
           ]
  end

  test "coerce passes through known atoms" do
    for k <- Error.kinds(), do: assert(Error.coerce(k) == k)
  end

  test "coerce maps unknowns to :unknown" do
    assert Error.coerce(:not_a_real_error) == :unknown
    assert Error.coerce("string") == :unknown
    assert Error.coerce(nil) == :unknown
  end
end
