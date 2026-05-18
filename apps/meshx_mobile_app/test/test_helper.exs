# Tests tagged :hardware_artifact read structured JSON manifests from
# artifacts/local-ble/.../manifests/, which are gitignored. They run
# against a developer machine that has them on disk; on CI the manifests
# are absent. Skip when missing rather than failing.
hardware_artifact_manifests =
  "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/manifests/focused-remaining-items-audit.json"

repo_root =
  case File.cwd!() do
    cwd ->
      if String.ends_with?(cwd, "/apps/meshx_mobile_app"),
        do: Path.expand("../..", cwd),
        else: cwd
  end

exclude =
  if File.exists?(Path.join(repo_root, hardware_artifact_manifests)) do
    []
  else
    [hardware_artifact: true]
  end

ExUnit.start(exclude: exclude)
