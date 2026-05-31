# Swift interop tests need Apple's Swift toolchain to build the
# Mob.NoiseInteropCLI peer (the harness imports CryptoKit, which is
# Apple-only — open-source Swift on Linux can't compile it). Skip when
# not on macOS / when xcrun is unavailable.
exclude =
  if :os.type() == {:unix, :darwin} and System.find_executable("xcrun") do
    []
  else
    [requires_swift: true]
  end

ExUnit.start(exclude: exclude)
