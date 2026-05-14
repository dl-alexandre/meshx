defmodule MeshxMobileApp.BLE.LocalReleaseEvidenceManifestTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.{LocalReleaseEvidenceManifest, LocalReleaseManifest}

  test "projects hardware validation gates into release evidence entries" do
    snapshot = LocalReleaseEvidenceManifest.snapshot()

    assert snapshot.manifest_version == 1
    assert snapshot.evidence_boundary == :local_ble_hardware_release_evidence
    assert snapshot.passed_count == 1
    assert snapshot.open_count == 4
    refute snapshot.release_candidate_complete?
  end

  test "passed Android beacon gossip gate supports only nearby beacon refs" do
    entry =
      LocalReleaseEvidenceManifest.snapshot().entries
      |> Enum.find(&(&1.gate_id == :android_legacy_beacon_gossip_one_hop))

    assert entry.status == :passed
    assert :advert_only_local_release in entry.required_for
    assert :nearby_beacon_refs in entry.required_for
    assert entry.missing_evidence == []
  end

  test "open gates keep missing evidence visible for release candidates" do
    open_ids = LocalReleaseEvidenceManifest.open_entries() |> Enum.map(& &1.gate_id)

    assert :android_full_envelope_advert_pair in open_ids
    assert :gatt_known_good_fetch in open_ids
    assert :advert_gossip_multi_hop_hardware in open_ids
    assert :ios_advert_only_participation in open_ids

    gatt =
      Enum.find(
        LocalReleaseEvidenceManifest.open_entries(),
        &(&1.gate_id == :gatt_known_good_fetch)
      )

    assert Enum.any?(gatt.missing_evidence, &String.contains?(&1, "Known-good hardware pair"))
  end

  test "local release manifest includes hardware evidence manifest" do
    manifest = LocalReleaseManifest.snapshot()

    assert manifest.hardware_evidence.open_count == 4
    refute manifest.hardware_evidence.release_candidate_complete?
    assert Enum.any?(manifest.required_artifacts, &(&1.id == :hardware_evidence_manifest))
  end

  test "json snapshot is machine readable" do
    snapshot = LocalReleaseEvidenceManifest.json_snapshot()

    assert snapshot["manifest_version"] == 1
    assert snapshot["open_count"] == 4
    assert snapshot["release_candidate_complete?"] == false
  end
end
