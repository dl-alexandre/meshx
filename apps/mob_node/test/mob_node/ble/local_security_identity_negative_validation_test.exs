defmodule Mob.Node.BLE.LocalSecurityIdentityNegativeValidationTest do
  use ExUnit.Case, async: true

  alias Mob.Node.BLE.LocalSecurityIdentityNegativeValidation

  test "snapshot keeps trusted and delivery claims blocked" do
    snapshot = LocalSecurityIdentityNegativeValidation.snapshot()

    assert snapshot.validation_version == 1
    assert snapshot.boundary == :current_unsigned_advertisement_only_mode
    refute snapshot.trusted_claims_allowed?
    refute snapshot.delivery_claims_allowed?
    assert snapshot.case_count == 5
  end

  test "unsigned full envelope remains a local unsigned message" do
    snapshot = LocalSecurityIdentityNegativeValidation.snapshot()
    validation = Enum.find(snapshot.cases, &(&1.id == :unsigned_full_envelope))

    assert validation.input == :received_message
    assert validation.expected_decision == :local_unsigned_message
    assert :trusted_message in validation.blocked_claims
    assert :message_authorship in validation.required_before_allowed
    assert :replay_protection in validation.required_before_allowed
  end

  test "legacy and gossiped beacon refs remain untrusted references" do
    snapshot = LocalSecurityIdentityNegativeValidation.snapshot()

    legacy = Enum.find(snapshot.cases, &(&1.id == :hash_only_legacy_beacon))
    gossip = Enum.find(snapshot.cases, &(&1.id == :gossiped_beacon_ref))

    assert legacy.expected_decision == :local_untrusted_reference
    assert gossip.expected_decision == :local_untrusted_reference
    assert :full_envelope_resolution in legacy.required_before_allowed
    assert :production_routing_policy in gossip.required_before_allowed
    assert :routed_delivery in gossip.blocked_claims
  end

  test "passive peer labels cannot become trusted identities" do
    snapshot = LocalSecurityIdentityNegativeValidation.snapshot()
    validation = Enum.find(snapshot.cases, &(&1.id == :passive_peer_label))

    assert validation.expected_decision == :unauthenticated_identity_signal
    assert :authenticated_peer_identity in validation.blocked_claims
    assert :identity_key_binding in validation.required_before_allowed
  end

  test "json snapshot is machine readable" do
    snapshot = LocalSecurityIdentityNegativeValidation.json_snapshot()

    assert snapshot["validation_version"] == 1
    assert snapshot["trusted_claims_allowed?"] == false
    assert snapshot["delivery_claims_allowed?"] == false

    assert Enum.any?(
             snapshot["cases"],
             &(&1["id"] == "hash_only_legacy_beacon" and
                 &1["expected_decision"] == "local_untrusted_reference")
           )
  end
end
