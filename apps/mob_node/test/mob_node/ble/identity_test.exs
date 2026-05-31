defmodule Mob.Node.BLE.IdentityTest do
  use ExUnit.Case, async: true

  alias Mob.Node.BLE.Identity

  describe "derive/1" do
    test "returns the local name when it carries the MeshX prefix (Complete Local Name)" do
      ad = <<12, 0x09, "meshx-alpha">>
      assert Identity.derive(ad) == "meshx-alpha"
    end

    test "returns the local name from a Shortened Local Name record" do
      ad = <<11, 0x08, "meshx-beta">>
      assert Identity.derive(ad) == "meshx-beta"
    end

    test "skips non-name records and finds a later local name" do
      # Flags (0x01), TX Power (0x0a), then a Complete Local Name.
      ad = <<2, 0x01, 0x06, 2, 0x0A, 0x0C, 12, 0x09, "meshx-alpha">>
      assert Identity.derive(ad) == "meshx-alpha"
    end

    test "returns nil for a local name without the MeshX prefix" do
      ad = <<10, 0x09, "airpods-x">>
      assert Identity.derive(ad) == nil
    end

    test "returns nil when no local-name record is present" do
      ad = <<2, 0x01, 0x06, 2, 0x0A, 0x0C>>
      assert Identity.derive(ad) == nil
    end

    test "returns nil for empty advertisement" do
      assert Identity.derive(<<>>) == nil
    end

    test "returns nil for malformed (truncated) advertisement" do
      # Record claims 30 bytes of data but the binary is shorter.
      assert Identity.derive(<<30, 0x09, "short">>) == nil
    end

    test "stops on zero-length padding" do
      # A `mob-alpha` record sitting behind padding is unreachable.
      ad = <<0, 12, 0x09, "meshx-alpha">>
      assert Identity.derive(ad) == nil
    end

    test "is deterministic — same bytes always produce the same result" do
      ad = <<12, 0x09, "meshx-alpha">>
      assert Identity.derive(ad) == Identity.derive(ad)
      assert Identity.derive(ad) == Identity.derive(ad)
    end

    test "real captured iPad advertisement derives `mob-ipad`" do
      ad =
        Base.decode64!(
          "AgEaAgoMCv9MABAFBBzMjFoLCW1lc2h4LWlwYWQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
        )

      assert Identity.derive(ad) == "meshx-ipad"
    end
  end

  describe "classify/1" do
    test "MeshX-named advertisement returns :advertised_name source" do
      assert %Identity.Claim{peer_id: "meshx-alpha", source: :advertised_name} =
               Identity.classify(<<12, 0x09, "meshx-alpha">>)
    end

    test "non-MeshX local name returns :none source with nil peer_id" do
      assert %Identity.Claim{peer_id: nil, source: :none} =
               Identity.classify(<<10, 0x09, "airpods-x">>)
    end

    test "no local-name record returns :none source" do
      assert %Identity.Claim{peer_id: nil, source: :none} =
               Identity.classify(<<2, 0x01, 0x06>>)
    end

    test "empty advertisement returns :none source" do
      assert %Identity.Claim{peer_id: nil, source: :none} = Identity.classify(<<>>)
    end

    test "Claim has reserved source values for future cryptographic evidence" do
      # The type spec declares :fingerprint and :signed_identity as
      # valid source values. They are not produced by classify/1
      # today, but the field accepts them so PeerTable.Entry doesn't
      # need to change shape when those codepaths land.
      assert :fingerprint in [:none, :advertised_name, :fingerprint, :signed_identity]
      assert :signed_identity in [:none, :advertised_name, :fingerprint, :signed_identity]
    end

    test "derive/1 stays consistent with classify/1.peer_id" do
      for ad <- [<<>>, <<2, 0x01, 0x06>>, <<10, 0x09, "airpods-x">>, <<12, 0x09, "meshx-alpha">>] do
        assert Identity.derive(ad) == Identity.classify(ad).peer_id
      end
    end
  end
end
