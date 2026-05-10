defmodule MeshxMob.PlatformTest do
  use ExUnit.Case

  alias MeshxMob.Platform

  test "builds platform context with defaults" do
    platform = Platform.new()

    assert platform.os == :unknown
    assert platform.background_mode == :foreground
    assert platform.permissions == MapSet.new()
    refute Platform.background?(platform)
    assert :ok = Platform.validate(platform)
  end

  test "tracks permissions" do
    platform = Platform.new(os: :ios, permissions: [:bluetooth])

    assert Platform.permission?(platform, :bluetooth)
    refute Platform.permission?(platform, :location)

    platform = Platform.grant(platform, :location)
    assert Platform.permission?(platform, :location)

    platform = Platform.revoke(platform, :bluetooth)
    refute Platform.permission?(platform, :bluetooth)
  end

  test "exports transport metadata" do
    platform =
      Platform.new(
        os: :android,
        background_mode: :background,
        permissions: [:location, :bluetooth],
        bridge: ExampleBridge,
        metadata: %{battery_optimized?: true}
      )

    assert Platform.background?(platform)

    assert %{
             mobile: %{
               os: :android,
               background_mode: :background,
               permissions: [:bluetooth, :location],
               bridge: ExampleBridge,
               metadata: %{battery_optimized?: true}
             }
           } = Platform.to_metadata(platform)
  end

  test "normalizes invalid background modes to foreground" do
    platform = Platform.new(background_mode: :invalid)

    assert platform.background_mode == :foreground
    assert :ok = Platform.validate(platform)
  end

  test "validate detects manually corrupted platform contexts" do
    assert {:error, {:invalid_background_mode, :paused}} =
             Platform.validate(%Platform{os: :ios, background_mode: :paused})

    assert {:error, :invalid_metadata} =
             Platform.validate(%Platform{os: :ios, metadata: [:not, :a, :map]})
  end
end
