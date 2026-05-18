# Swift interop tests need the Swift toolchain (xcrun/swift) to build the
# MeshxNoiseInteropCLI peer. Skip when neither binary is on PATH (Linux CI).
exclude =
  if System.find_executable("xcrun") || System.find_executable("swift") do
    []
  else
    [requires_swift: true]
  end

ExUnit.start(exclude: exclude)
