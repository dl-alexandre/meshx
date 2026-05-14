defmodule MeshxMobileApp.BLE.LocalSecurityReleaseEvidenceReviewTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.LocalSecurityReleaseEvidenceReview

  test "review is ready when every security validation gate has operator-reviewed evidence" do
    review = LocalSecurityReleaseEvidenceReview.review(complete_input())

    assert review.boundary == :local_security_release_evidence_review
    assert review.status == :ready
    assert review.security_release_evidence_complete?
    assert review.missing == []
    assert review.missing_plan_gate_ids == []
    assert review.missing_blocked_claims == []
    refute review.authenticated_peer_identity_claim_allowed?
    refute review.authenticated_message_claim_allowed?
    refute review.trusted_message_claim_allowed?
    refute review.trusted_delivery_claim_allowed?
  end

  test "review stays open when manifests and attachments are absent" do
    review = LocalSecurityReleaseEvidenceReview.review(%{})

    assert review.status == :open
    refute review.security_release_evidence_complete?
    assert "Missing readiness_manifest_path." in review.missing
    assert "Missing release_manifest_path." in review.missing
    assert "Missing security_manifest_path." in review.missing
    assert "Missing at least one security attachment." in review.missing

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "Missing security plan gate evidence")
           )
  end

  test "attachments must include metadata and plan gate ids" do
    review =
      complete_input()
      |> Map.put(:security_attachments, [
        %{
          artifact_id: "",
          path: nil,
          source: " ",
          plan_gate_ids: [],
          evidence_types_by_gate: %{},
          blocked_claims_called_out: LocalSecurityReleaseEvidenceReview.required_blocked_claims(),
          operator_reviewed?: true
        }
      ])
      |> LocalSecurityReleaseEvidenceReview.review()

    assert "Security attachment 1 missing artifact_id." in review.missing
    assert "Security attachment 1 missing path." in review.missing
    assert "Security attachment 1 missing source." in review.missing
    assert "Security attachment 1 missing plan_gate_ids." in review.missing
  end

  test "manifest and attachment paths must be release-relative" do
    review =
      complete_input()
      |> Map.put(:readiness_manifest_path, "/tmp/local-readiness.json")
      |> Map.put(:release_manifest_path, "../outside/local-release.json")
      |> Map.put(:security_manifest_path, "https://example.invalid/security.json")
      |> put_in([:security_attachments, Access.at(0), :path], "file:///tmp/security.json")
      |> LocalSecurityReleaseEvidenceReview.review()

    assert review.status == :open
    assert "readiness_manifest_path must be a relative artifact path." in review.missing
    assert "release_manifest_path must be a relative artifact path." in review.missing
    assert "security_manifest_path must be a relative artifact path." in review.missing
    assert "Security attachment 1 path must be a relative artifact path." in review.missing
  end

  test "manifest and attachment text fields must be strings and not need trimming" do
    review =
      complete_input()
      |> Map.put(:readiness_manifest_path, 123)
      |> Map.put(:release_manifest_path, " tmp/local-release.json")
      |> Map.put(:security_manifest_path, "tmp/local-security-evidence.json ")
      |> put_in([:security_attachments, Access.at(0), :artifact_id], 456)
      |> put_in([:security_attachments, Access.at(0), :path], " tmp/local-security-evidence.json")
      |> put_in([:security_attachments, Access.at(0), :source], "LocalSecurityFixtureAudit ")
      |> LocalSecurityReleaseEvidenceReview.review()

    assert review.status == :open
    assert "readiness_manifest_path must be a string." in review.missing
    assert "release_manifest_path must not have leading or trailing whitespace." in review.missing

    assert "security_manifest_path must not have leading or trailing whitespace." in review.missing

    assert "Security attachment 1 artifact_id must be a string." in review.missing

    assert "Security attachment 1 path must not have leading or trailing whitespace." in review.missing

    assert "Security attachment 1 source must not have leading or trailing whitespace." in review.missing
  end

  test "security attachments container must be a list" do
    review =
      complete_input()
      |> Map.put(:security_attachments, %{"bad" => "shape"})
      |> LocalSecurityReleaseEvidenceReview.review()

    assert review.status == :open
    assert "security_attachments must be a list." in review.missing
    assert "Missing at least one security attachment." in review.missing
  end

  test "attachment nested containers must have expected shapes" do
    review =
      complete_input()
      |> put_in([:security_attachments, Access.at(0), :plan_gate_ids], "peer_key_enrollment")
      |> put_in([:security_attachments, Access.at(0), :evidence_types_by_gate], [
        :peer_key_enrollment
      ])
      |> put_in([:security_attachments, Access.at(0), :blocked_claims_called_out], %{
        trusted_message: true
      })
      |> LocalSecurityReleaseEvidenceReview.review()

    assert review.status == :open
    assert "Security attachment 1 plan_gate_ids must be a list." in review.missing
    assert "Security attachment 1 evidence_types_by_gate must be an object." in review.missing
    assert "Security attachment 1 blocked_claims_called_out must be a list." in review.missing
  end

  test "attachments must declare the required evidence type for each covered gate" do
    review =
      complete_input()
      |> put_in(
        [
          :security_attachments,
          Access.at(0),
          :evidence_types_by_gate,
          :beacon_ref_authentication_integration
        ],
        :authorship_fixture_matrix
      )
      |> LocalSecurityReleaseEvidenceReview.review()

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "beacon_ref_authentication_integration evidence_type must be :beacon_authentication_fixture"
             )
           )
  end

  test "unknown attachment plan gate ids fail closed instead of raising" do
    review =
      complete_input()
      |> put_in([:security_attachments, Access.at(0), :plan_gate_ids], [
        :peer_key_enrollment,
        :unknown_security_gate
      ])
      |> LocalSecurityReleaseEvidenceReview.review()

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "unknown plan_gate_id :unknown_security_gate")
           )
  end

  test "review requires blocked claim callouts and operator review" do
    review =
      complete_input()
      |> put_in([:security_attachments, Access.at(0), :blocked_claims_called_out], [
        :trusted_delivery
      ])
      |> put_in([:security_attachments, Access.at(0), :operator_reviewed?], false)
      |> LocalSecurityReleaseEvidenceReview.review()

    assert "Security attachments must be operator reviewed." in review.missing

    assert Enum.any?(
             review.missing,
             &String.contains?(&1, "Missing security blocked claim callouts")
           )
  end

  test "operator review flag must be boolean" do
    review =
      complete_input()
      |> put_in([:security_attachments, Access.at(0), :operator_reviewed?], "true")
      |> LocalSecurityReleaseEvidenceReview.review()

    assert review.status == :open
    assert "Security attachments must be operator reviewed." in review.missing
    assert "Security attachment 1 operator_reviewed? must be a boolean." in review.missing
  end

  test "attachments must call out gate-specific blocked security claims" do
    review =
      complete_input()
      |> put_in(
        [:security_attachments, Access.at(0), :blocked_claims_called_out],
        LocalSecurityReleaseEvidenceReview.required_blocked_claims()
      )
      |> LocalSecurityReleaseEvidenceReview.review()

    assert review.status == :open

    assert Enum.any?(
             review.missing,
             &String.contains?(
               &1,
               "peer_key_enrollment missing gate-specific blocked claim callouts"
             )
           )
  end

  test "JSON review preserves blocked security claims" do
    review = LocalSecurityReleaseEvidenceReview.json_review(complete_input())

    assert review["boundary"] == "local_security_release_evidence_review"
    assert review["status"] == "ready"
    assert review["trusted_message_claim_allowed?"] == false
    assert review["trusted_delivery_claim_allowed?"] == false
    assert review["missing_plan_gate_ids"] == []
  end

  test "template input lists every gate but cannot pass as complete evidence" do
    template = LocalSecurityReleaseEvidenceReview.template_input()

    assert template["readiness_manifest_path"] == ""
    assert template["release_manifest_path"] == ""
    assert template["security_manifest_path"] == ""

    [attachment] = template["security_attachments"]

    assert attachment["plan_gate_ids"] ==
             Enum.map(
               LocalSecurityReleaseEvidenceReview.required_plan_gate_ids(),
               &Atom.to_string/1
             )

    assert attachment["evidence_types_by_gate"] ==
             LocalSecurityReleaseEvidenceReview.required_evidence_types()
             |> Map.new(fn {gate_id, evidence_type} ->
               {Atom.to_string(gate_id), Atom.to_string(evidence_type)}
             end)

    assert attachment["blocked_claims_called_out"] == []
    assert attachment["operator_reviewed?"] == false

    review = LocalSecurityReleaseEvidenceReview.review(template)

    assert review.status == :open
    refute review.security_release_evidence_complete?
    refute review.trusted_message_claim_allowed?
    refute review.trusted_delivery_claim_allowed?
  end

  test "review accepts string-keyed JSON metadata" do
    review =
      complete_input()
      |> JSON.encode!()
      |> JSON.decode!()
      |> LocalSecurityReleaseEvidenceReview.review()

    assert review.status == :ready
    assert review.security_release_evidence_complete?
    assert review.missing == []
  end

  defp complete_input do
    %{
      readiness_manifest_path: "tmp/local-readiness.json",
      release_manifest_path: "tmp/local-release.json",
      security_manifest_path: "tmp/local-security-evidence.json",
      security_attachments: [
        %{
          artifact_id: "security-fixture-audit",
          path: "tmp/local-security-evidence.json",
          source: "LocalSecurityFixtureAudit and LocalSecurityAcceptance",
          plan_gate_ids: LocalSecurityReleaseEvidenceReview.required_plan_gate_ids(),
          evidence_types_by_gate: complete_evidence_types_by_gate(),
          blocked_claims_called_out: complete_blocked_claims(),
          operator_reviewed?: true
        }
      ]
    }
  end

  defp complete_blocked_claims do
    gate_claims =
      LocalSecurityReleaseEvidenceReview.required_gate_blocked_claims()
      |> Map.values()
      |> List.flatten()

    (LocalSecurityReleaseEvidenceReview.required_blocked_claims() ++ gate_claims)
    |> Enum.uniq()
  end

  defp complete_evidence_types_by_gate do
    LocalSecurityReleaseEvidenceReview.required_evidence_types()
  end
end
