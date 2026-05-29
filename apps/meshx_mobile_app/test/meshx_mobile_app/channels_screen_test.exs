defmodule MeshxMobileApp.ChannelsScreenTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.ChannelsScreen

  describe "normalize_channel/1" do
    test "rejects nil and empty / whitespace-only input" do
      assert {:error, "Channel name is required"} = ChannelsScreen.normalize_channel(nil)
      assert {:error, "Channel name is required"} = ChannelsScreen.normalize_channel("")
      assert {:error, "Channel name is required"} = ChannelsScreen.normalize_channel("   ")
    end

    test "rejects names containing spaces" do
      assert {:error, "Channel name cannot contain spaces"} =
               ChannelsScreen.normalize_channel("#hello world")

      assert {:error, "Channel name cannot contain spaces"} =
               ChannelsScreen.normalize_channel("hello world")
    end

    test "prepends '#' when missing and trims surrounding whitespace" do
      assert {:ok, "#random"} = ChannelsScreen.normalize_channel("random")
      assert {:ok, "#random"} = ChannelsScreen.normalize_channel("  random  ")
    end

    test "preserves an explicit leading '#'" do
      assert {:ok, "#general"} = ChannelsScreen.normalize_channel("#general")
      assert {:ok, "##weird"} = ChannelsScreen.normalize_channel("##weird")
    end
  end
end
