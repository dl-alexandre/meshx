defmodule Mix.Tasks.MeshxMobileReleaseCITest do
  use ExUnit.Case, async: true

  @workflow Path.expand("../../../../../.github/workflows/ci.yml", __DIR__)
  @release_doc Path.expand("../../../../../docs/RELEASE.md", __DIR__)
  @artifact_bundle_doc Path.expand("../../../../../docs/local_ble_release_artifact_bundle.md", __DIR__)

  test "CI generates local mobile release manifests" do
    workflow = File.read!(@workflow)

    assert workflow =~
             "mix meshx.mobile.local_readiness.audit --allow-open --out tmp/ci-local-readiness.json"

    assert workflow =~
             "mix meshx.mobile.local_completion.blocker_matrix --json --out tmp/ci-local-completion-blocker-matrix.json"

    assert workflow =~
             "mix meshx.mobile.local_completion.audit --allow-open | tee tmp/ci-local-completion-audit.txt"

    assert workflow =~
             "mix meshx.mobile.local_completion.audit --allow-open --json --out tmp/ci-local-completion-audit.json"

    assert workflow =~
             "mix meshx.mobile.local_release.artifact_bundle --json --out tmp/ci-local-release-artifact-bundle.json"

    assert workflow =~
             "mix meshx.mobile.local_release.manifest --json --out tmp/ci-local-release.json"

    assert workflow =~ ~s(blocker_matrix["completion_claim_allowed?"] == false)
    assert workflow =~ ~s(completion_audit["completion_claim_allowed?"] == false)
    assert workflow =~
             "plain_completion_audit = File.read!(\"tmp/ci-local-completion-audit.txt\")"

    assert workflow =~ "String.contains?(plain_completion_audit, \"OPEN_ITEMS 10\")"

    assert workflow =~
             "String.contains?(plain_completion_audit, \"OPEN_ITEM objective=full_message_resolution status=blocked\")"

    assert workflow =~
             "String.contains?(plain_completion_audit, \"OPEN_ITEM objective=release_hardening status=partial\")"

    assert workflow =~ ~s(artifact_bundle["release_candidate_complete?"] == false)
    assert workflow =~ ~s(artifact_bundle["required_commands"])
    assert workflow =~ ~s(local_release.manifest)
    assert workflow =~ ~s(local-completion-audit.txt)
    assert workflow =~ ~s(release["whole_project_complete?"] == false)
    assert workflow =~ ~s(release["policy_gates"]["routing"]["routing_claims_allowed?"] == false)
  end

  test "release docs require plain-text completion audit open item review" do
    release_doc = File.read!(@release_doc)
    artifact_bundle_doc = File.read!(@artifact_bundle_doc)

    assert release_doc =~
             "mix meshx.mobile.local_completion.audit --allow-open | tee tmp/local-completion-audit.txt"

    for doc <- [release_doc, artifact_bundle_doc] do
      assert doc =~ "OPEN_ITEMS 10"
      assert doc =~ "OPEN_ITEM"
      assert doc =~ "remaining"
      assert doc =~ "objective"
    end

    assert artifact_bundle_doc =~ "OPEN_ITEM objective=... status=... missing=..."
  end
end
