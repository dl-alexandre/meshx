defmodule MeshxMobileApp.BLE.LocalRequiredCommandPathsTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.{
    LocalFullMessageResolutionEvidenceManifest,
    LocalIOSParityEvidenceManifest,
    LocalInboxUxEvidenceManifest,
    LocalLifecycleEvidenceManifest,
    LocalMultiHopHardwareEvidenceManifest,
    LocalPersistenceEvidenceManifest,
    LocalProjectCompletionAudit,
    LocalReleaseArtifactBundle,
    LocalReleaseManifest,
    LocalRoutingEvidenceManifest,
    LocalSecurityEvidenceManifest
  }

  @snapshots [
    LocalFullMessageResolutionEvidenceManifest,
    LocalIOSParityEvidenceManifest,
    LocalInboxUxEvidenceManifest,
    LocalLifecycleEvidenceManifest,
    LocalMultiHopHardwareEvidenceManifest,
    LocalPersistenceEvidenceManifest,
    LocalProjectCompletionAudit,
    LocalReleaseArtifactBundle,
    LocalReleaseManifest,
    LocalRoutingEvidenceManifest,
    LocalSecurityEvidenceManifest
  ]

  @repo_root Path.expand("../../../../..", __DIR__)

  test "path-specific required mix test commands point at checked-in tests" do
    missing_paths =
      @snapshots
      |> Enum.flat_map(&commands_for/1)
      |> Enum.flat_map(&test_paths/1)
      |> Enum.reject(&File.exists?(Path.join(@repo_root, &1)))
      |> Enum.uniq()
      |> Enum.sort()

    assert missing_paths == []
  end

  defp commands_for(module) do
    module.snapshot()
    |> Map.fetch!(:required_commands)
  end

  defp test_paths("mix test " <> rest) do
    rest
    |> String.split(" ", trim: true)
    |> Enum.filter(&(String.starts_with?(&1, "apps/") and String.ends_with?(&1, ".exs")))
  end

  defp test_paths(_command), do: []
end
