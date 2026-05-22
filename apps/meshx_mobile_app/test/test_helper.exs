# Tests tagged :hardware_artifact read structured JSON manifests from
# artifacts/local-ble/.../manifests/, which are gitignored. They run
# against a developer machine that has them on disk; on CI the manifests
# are absent. Skip when missing rather than failing.
hardware_artifact_manifests =
  "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/manifests/focused-remaining-items-audit.json"

# Robust repo root detection via __DIR__ (test/ is 3 levels under repo root).
# This works regardless of current working directory (mix test from root vs. app dir,
# symlinks, CI, unusual shells, etc.) unlike the previous cwd-ends-with heuristic.
repo_root = Path.expand("../../../", __DIR__)

exclude =
  if File.exists?(Path.join(repo_root, hardware_artifact_manifests)) do
    []
  else
    [hardware_artifact: true]
  end

ExUnit.start(exclude: exclude)
