defmodule MeshxMobileApp.BLE.CaptureTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.Capture

  describe "from_logcat_line/1" do
    test "passes through bare JSON payloads" do
      assert ~s({"event":"device_discovered"}) =
               Capture.from_logcat_line(~s({"event":"device_discovered"}))
    end

    test "extracts native MeshxBle payloads" do
      line = ~s(05-24 12:00:00.000 123 456 I MeshxBle: {"event":"device_discovered"})

      assert ~s({"event":"device_discovered"}) = Capture.from_logcat_line(line)
    end

    test "extracts app reliability event payloads" do
      line =
        ~s(05-24 12:00:00.000 123 456 I Elixir: MeshxAppEvent: {"schema":"meshx_rt_event.v1","event":"selftest_heartbeat"})

      assert ~s({"schema":"meshx_rt_event.v1","event":"selftest_heartbeat"}) =
               Capture.from_logcat_line(line)
    end

    test "ignores unrelated logcat lines" do
      assert Capture.from_logcat_line("05-24 I OtherTag: not ours") == nil
    end
  end
end
