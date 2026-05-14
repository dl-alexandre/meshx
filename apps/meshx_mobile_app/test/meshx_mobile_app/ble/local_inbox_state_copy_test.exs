defmodule MeshxMobileApp.BLE.LocalInboxStateCopyTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.LocalInboxStateCopy

  test "defines stable copy for every nearby-message state" do
    states = Enum.map(LocalInboxStateCopy.all(), & &1.state)

    assert states == [:full_message, :unresolved_ref, :gossiped_ref, :stale_ref]
  end

  test "full messages stay explicit without claiming delivery" do
    copy = LocalInboxStateCopy.for_state(:full_message)

    assert copy.badge == "full"
    assert copy.severity == :ready
    assert copy.limitation =~ "MessageEnvelope"
    assert "not a delivery receipt" in copy.blocked_claims
    assert "not authenticated authorship" in copy.blocked_claims
    refute copy.delivery_claim_allowed?
  end

  test "beacon ref states keep pointer and transport limits visible" do
    unresolved = LocalInboxStateCopy.for_state(:unresolved_ref)
    gossiped = LocalInboxStateCopy.for_state(:gossiped_ref)
    stale = LocalInboxStateCopy.for_state(:stale_ref)

    assert unresolved.severity == :needs_transport
    assert unresolved.limitation =~ "pointer"
    assert unresolved.next_action =~ "validated fetch transport"
    assert "not fetch success" in unresolved.blocked_claims

    assert gossiped.severity == :informational
    assert gossiped.limitation =~ "not guaranteed delivery"
    assert "not multi-hop hardware proof" in gossiped.blocked_claims

    assert stale.severity == :stale
    assert stale.next_action =~ "old nearby evidence"
    assert "not current nearby presence" in stale.blocked_claims

    refute unresolved.delivery_claim_allowed?
    refute gossiped.delivery_claim_allowed?
    refute stale.delivery_claim_allowed?
  end

  test "json snapshot is machine readable" do
    snapshot = LocalInboxStateCopy.json_snapshot()

    assert snapshot["state_copy_version"] == 1
    assert Enum.any?(snapshot["states"], &(&1["state"] == "unresolved_ref"))
    assert Enum.any?(snapshot["states"], &("blocked_claims" in Map.keys(&1)))
  end
end
