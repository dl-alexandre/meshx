defmodule MeshxMobileApp.IOSManifestTest do
  use ExUnit.Case, async: true

  @manifest Path.expand("../../ios/Info.plist", __DIR__)

  test "iOS app is declared as a universal single-window app" do
    plist = File.read!(@manifest)

    assert plist =~ "<key>UIDeviceFamily</key>"
    assert plist =~ "<integer>1</integer>"
    assert plist =~ "<integer>2</integer>"
    assert plist =~ "<key>UIRequiresFullScreen</key>"
    assert plist =~ "<key>UISupportedInterfaceOrientations~ipad</key>"
    assert plist =~ "<key>UIApplicationSupportsMultipleScenes</key>"
    assert plist =~ "<false/>"
  end
end
