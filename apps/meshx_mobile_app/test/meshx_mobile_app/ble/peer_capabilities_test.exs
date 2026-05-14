defmodule MeshxMobileApp.BLE.PeerCapabilitiesTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.PeerCapabilities

  describe "parse/1 — no MeshX record present" do
    test "empty advertisement returns all-false defaults" do
      caps = PeerCapabilities.parse(<<>>)
      assert caps.protocol_version == nil
      assert PeerCapabilities.mesh_x_capable?(caps) == false
      assert caps.supports_replay_contract == false
      assert caps.supports_passive_presence == false
      assert caps.supports_churn == false
    end

    test "advertisement with only a Local Name returns defaults" do
      caps = PeerCapabilities.parse(<<12, 0x09, "meshx-alpha">>)
      assert caps.protocol_version == nil
      assert PeerCapabilities.mesh_x_capable?(caps) == false
    end

    test "Manufacturer Specific Data without MX marker returns defaults" do
      # 0xFF record with "XX" instead of "MX"
      caps = PeerCapabilities.parse(<<5, 0xFF, "XX", 1, 0x07>>)
      assert caps.protocol_version == nil
    end
  end

  describe "parse/1 — v1 capabilities" do
    test "all three observation capabilities set" do
      caps = PeerCapabilities.parse(<<5, 0xFF, "MX", 1, 0x07>>)
      assert caps.protocol_version == 1
      assert PeerCapabilities.mesh_x_capable?(caps) == true
      assert caps.supports_replay_contract == true
      assert caps.supports_passive_presence == true
      assert caps.supports_churn == true
      assert caps.supports_message_exchange == false
      assert caps.supports_crypto_identity == false
      assert caps.unknown_payload == <<>>
    end

    test "individual bits decode correctly" do
      # bit 0 only
      assert %{
               supports_replay_contract: true,
               supports_passive_presence: false,
               supports_churn: false
             } =
               PeerCapabilities.parse(<<5, 0xFF, "MX", 1, 0x01>>)

      # bit 2 only
      assert %{supports_replay_contract: false, supports_churn: true} =
               PeerCapabilities.parse(<<5, 0xFF, "MX", 1, 0x04>>)
    end

    test "reserved bits 3 and 4 decode even though runtime won't trust them" do
      # 0x18 = bits 3,4 set (message_exchange + crypto_identity)
      caps = PeerCapabilities.parse(<<5, 0xFF, "MX", 1, 0x18>>)
      assert caps.supports_message_exchange == true
      assert caps.supports_crypto_identity == true
    end

    test "capabilities AD before Local Name AD is found" do
      ad = <<5, 0xFF, "MX", 1, 0x07, 12, 0x09, "meshx-alpha">>
      assert PeerCapabilities.parse(ad).protocol_version == 1
    end

    test "Local Name AD before capabilities AD is also found" do
      ad = <<12, 0x09, "meshx-alpha", 5, 0xFF, "MX", 1, 0x07>>
      assert PeerCapabilities.parse(ad).protocol_version == 1
    end
  end

  describe "parse/1 — unknown future version" do
    test "v2 with trailing bytes preserves unknown_payload" do
      caps = PeerCapabilities.parse(<<7, 0xFF, "MX", 2, 0x1F, 0xAA, 0xBB>>)
      assert caps.protocol_version == 2
      # v1-compatible flag bits still decode
      assert caps.supports_replay_contract == true
      assert caps.supports_passive_presence == true
      assert caps.supports_churn == true
      assert caps.supports_message_exchange == true
      assert caps.supports_crypto_identity == true
      assert caps.unknown_payload == <<0xAA, 0xBB>>
    end

    test "future version with just the version byte stays at flag defaults" do
      # length = 4 = 0xFF (type) + "MX" (2 bytes marker) + version byte (1)
      caps = PeerCapabilities.parse(<<4, 0xFF, "MX", 5>>)
      assert caps.protocol_version == 5
      assert caps.supports_replay_contract == false
    end
  end

  describe "parse/1 — malformed input" do
    test "truncated AD record returns defaults" do
      # Length byte says 10 but only 3 bytes follow
      caps = PeerCapabilities.parse(<<10, 0xFF, "MX">>)
      assert caps.protocol_version == nil
    end

    test "MX marker without version byte returns defaults" do
      # length=3 covers type(0xFF) + "MX" (2 bytes), so the version
      # byte is absent — parser sees an empty post-marker payload.
      caps = PeerCapabilities.parse(<<3, 0xFF, "MX", 12, 0x09, "meshx-gamma">>)
      assert caps.protocol_version == nil
    end

    test "v1 declared but no flags byte" do
      caps = PeerCapabilities.parse(<<4, 0xFF, "MX", 1>>)
      assert caps.protocol_version == 1
      assert caps.supports_replay_contract == false
    end

    test "zero-length terminator stops the walk" do
      # 0x00 length terminates AD; the MX record after it is unreachable.
      ad = <<0, 5, 0xFF, "MX", 1, 0x07>>
      assert PeerCapabilities.parse(ad).protocol_version == nil
    end

    test "non-binary input returns defaults without crashing" do
      assert %PeerCapabilities{protocol_version: nil} = PeerCapabilities.parse(nil)
      assert %PeerCapabilities{protocol_version: nil} = PeerCapabilities.parse(123)
    end
  end

  describe "determinism" do
    test "same bytes always produce identical struct" do
      ad = <<5, 0xFF, "MX", 1, 0x07, 12, 0x09, "meshx-alpha">>
      assert PeerCapabilities.parse(ad) == PeerCapabilities.parse(ad)
    end
  end
end
