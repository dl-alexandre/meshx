defmodule MeshxMobileApp.BLE.LocalIOSAdvertCarrierDecisionTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.LocalIOSAdvertCarrierDecision

  test "snapshot separates iOS observe and foreground emit implementation from gossip claims" do
    snapshot = LocalIOSAdvertCarrierDecision.snapshot()

    assert snapshot.boundary == :ios_advert_only_carrier_decision
    assert snapshot.current_ios_observe_carrier == :manufacturer_data_legacy_beacon_observe
    assert snapshot.current_ios_emit_carrier == :manufacturer_data_legacy_beacon_emit
    assert snapshot.ios_legacy_beacon_observe_implemented?
    assert snapshot.ios_legacy_beacon_observe_hardware_validated?
    assert snapshot.ios_legacy_beacon_emit_implemented?
    refute snapshot.ios_legacy_beacon_emit_cross_radio_validated?
    refute snapshot.ios_full_mx_direct_advert_receive_allowed?
    refute snapshot.ios_legacy_beacon_gossip_implemented?
    refute snapshot.ios_legacy_beacon_gossip_claim_allowed?
    refute snapshot.ios_parity_claim_allowed?
  end

  test "manufacturer-data observe carrier is hardware-validated for legacy beacons" do
    carrier =
      LocalIOSAdvertCarrierDecision.carriers()
      |> Enum.find(&(&1.id == :manufacturer_data_legacy_beacon_observe))

    assert carrier.direction == :observe
    assert carrier.status == :hardware_validated
    refute :ios_hardware_participation in carrier.blocked_claims
    refute :ios_legacy_beacon_observed in carrier.blocked_claims
    assert Enum.any?(carrier.evidence, &String.contains?(&1, "2026-05-15-iphone13-sm-t577u"))
  end

  test "full MX extended-advert observe remains PHY-blocked on iOS" do
    carrier =
      LocalIOSAdvertCarrierDecision.carriers()
      |> Enum.find(&(&1.id == :full_mx_extended_advert_observe))

    assert carrier.direction == :observe
    assert carrier.status == :phy_blocked
    assert :ios_full_mx_direct_advert_receive in carrier.blocked_claims
    assert :ios_full_envelope_advert_direct in carrier.blocked_claims

    assert Enum.any?(
             carrier.notes,
             &String.contains?(&1, "MB legacy beacon + GATT fetch")
           )
  end

  test "foreground emit carrier still does not allow iOS beacon gossip claims" do
    emit_carriers =
      LocalIOSAdvertCarrierDecision.carriers()
      |> Enum.filter(&(&1.direction == :emit))

    assert Enum.any?(emit_carriers, &(&1.id == :manufacturer_data_legacy_beacon_emit))
    assert Enum.any?(emit_carriers, &(&1.id == :service_uuid_identity_advert))
    assert Enum.any?(emit_carriers, &(&1.id == :service_data_beacon_ref))

    beacon_emit = Enum.find(emit_carriers, &(&1.id == :manufacturer_data_legacy_beacon_emit))
    assert beacon_emit.status == :implemented_unvalidated

    assert Enum.any?(
             beacon_emit.notes,
             &String.contains?(&1, "zero matched Android receive lines")
           )

    assert Enum.all?(emit_carriers, &(:ios_parity_claim in &1.blocked_claims))
  end

  test "service UUID identity advert is explicitly insufficient as a beacon ref carrier" do
    carrier =
      LocalIOSAdvertCarrierDecision.carriers()
      |> Enum.find(&(&1.id == :service_uuid_identity_advert))

    assert carrier.status == :insufficient_for_beacon_ref

    assert Enum.any?(
             carrier.notes,
             &String.contains?(&1, "does not carry message_id_hash")
           )
  end

  test "JSON snapshot preserves blocked claims and candidate statuses" do
    snapshot = LocalIOSAdvertCarrierDecision.json_snapshot()

    assert snapshot["boundary"] == "ios_advert_only_carrier_decision"
    assert snapshot["current_ios_emit_carrier"] == "manufacturer_data_legacy_beacon_emit"
    assert snapshot["ios_legacy_beacon_observe_hardware_validated?"] == true
    assert snapshot["ios_legacy_beacon_emit_implemented?"] == true
    assert snapshot["ios_legacy_beacon_emit_cross_radio_validated?"] == false
    assert snapshot["ios_full_mx_direct_advert_receive_allowed?"] == false
    assert snapshot["ios_legacy_beacon_gossip_claim_allowed?"] == false
    assert "ios_legacy_beacon_gossip" in snapshot["blocked_claims"]
    assert "ios_full_mx_direct_advert_receive" in snapshot["blocked_claims"]

    assert Enum.any?(
             snapshot["carriers"],
             &(&1["id"] == "service_data_beacon_ref" and
                 &1["status"] == "rejected")
           )
  end
end
