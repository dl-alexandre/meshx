defmodule MeshxMobileApp.BLE.PresencePolicyTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.PresencePolicy

  describe "derive/3 — default policy (10s active, 30s stale)" do
    setup do
      %{policy: PresencePolicy.default()}
    end

    test "fresh sighting is :active", %{policy: p} do
      assert :active = PresencePolicy.derive(1000, 1000, p)
    end

    test "exact boundary of active window is still :active", %{policy: p} do
      # delta = 10_000 ms
      assert :active = PresencePolicy.derive(0, 10_000, p)
    end

    test "one ms past active window is :stale", %{policy: p} do
      assert :stale = PresencePolicy.derive(0, 10_001, p)
    end

    test "exact boundary of active+stale window is still :stale", %{policy: p} do
      # delta = 40_000 ms
      assert :stale = PresencePolicy.derive(0, 40_000, p)
    end

    test "one ms past the combined window is :expired", %{policy: p} do
      assert :expired = PresencePolicy.derive(0, 40_001, p)
    end

    test "far in the past is :expired", %{policy: p} do
      assert :expired = PresencePolicy.derive(0, 999_999_999, p)
    end

    test "now < last_seen_at (clock skew) is treated as :active", %{policy: p} do
      # Defensive: a negative delta shouldn't flip the peer to expired
      # just because of arithmetic inversion (replay out-of-order,
      # cross-clock-source comparison, etc.).
      assert :active = PresencePolicy.derive(1_000, 500, p)
    end
  end

  describe "derive/3 — custom policy" do
    test "tight windows expire peers quickly" do
      tight = %PresencePolicy{active_window_ms: 100, stale_window_ms: 200}
      assert :active = PresencePolicy.derive(0, 100, tight)
      assert :stale = PresencePolicy.derive(0, 200, tight)
      assert :expired = PresencePolicy.derive(0, 500, tight)
    end

    test "loose windows keep peers active for a long time" do
      loose = %PresencePolicy{active_window_ms: 60_000, stale_window_ms: 600_000}
      assert :active = PresencePolicy.derive(0, 30_000, loose)
      assert :stale = PresencePolicy.derive(0, 300_000, loose)
      assert :expired = PresencePolicy.derive(0, 10_000_000, loose)
    end
  end

  describe "determinism" do
    test "same inputs always yield the same output" do
      p = PresencePolicy.default()
      assert PresencePolicy.derive(1000, 5000, p) == PresencePolicy.derive(1000, 5000, p)
      assert PresencePolicy.derive(1000, 50_000, p) == PresencePolicy.derive(1000, 50_000, p)
    end
  end
end
