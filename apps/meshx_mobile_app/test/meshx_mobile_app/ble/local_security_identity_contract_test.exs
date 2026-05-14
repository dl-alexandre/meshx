defmodule MeshxMobileApp.BLE.LocalSecurityIdentityContractTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.{LocalInbox, LocalSecurityIdentityContract}

  test "authorship proof requirement is explicit and unimplemented" do
    assert {:ok, requirement} = LocalSecurityIdentityContract.get(:message_authorship)

    assert requirement.status == :not_implemented
    assert Enum.any?(requirement.required_evidence, &String.contains?(&1, "MessageEnvelope"))
    assert requirement.current_gap =~ "do not prove who authored"
  end

  test "beacon refs cannot be promoted to trusted message delivery by themselves" do
    assert {:ok, requirement} = LocalSecurityIdentityContract.get(:beacon_ref_authentication)

    assert requirement.status == :not_implemented
    assert Enum.any?(requirement.required_evidence, &String.contains?(&1, "hash-only beacon"))

    assert Enum.any?(
             requirement.notes,
             &String.contains?(&1, "not messages with authorship proof")
           )
  end

  test "snapshot lists all open security identity requirements" do
    snapshot = LocalSecurityIdentityContract.snapshot()
    ids = Enum.map(snapshot.open_requirements, & &1.id)

    assert snapshot.open_requirement_count == 5
    assert :authenticated_peer_identity in ids
    assert :message_authorship in ids
    assert :replay_protection in ids
    assert :trust_policy in ids
    assert :beacon_ref_authentication in ids
  end

  test "local inbox snapshot exposes security identity contract" do
    snapshot = LocalInbox.new() |> LocalInbox.snapshot()

    assert snapshot.security_identity_contract.open_requirement_count == 5

    assert Enum.any?(
             snapshot.security_identity_contract.notes,
             &String.contains?(&1, "not authenticated")
           )
  end
end
