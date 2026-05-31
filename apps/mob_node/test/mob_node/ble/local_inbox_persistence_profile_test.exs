defmodule Mob.Node.BLE.LocalInboxPersistenceProfileTest do
  use ExUnit.Case, async: true

  alias Mob.Node.BLE.{LocalInboxPersistencePolicy, LocalInboxPersistenceProfile}

  test "memory-only profile is the explicit default boundary" do
    profile = LocalInboxPersistenceProfile.memory_only()

    assert profile.profile_version == 1
    assert profile.mode == :memory_only
    refute profile.enabled?
    refute profile.restore_on_start?
    assert profile.save_triggers == []

    assert profile.session_options == [
             persist_local_inbox?: false,
             restore_local_inbox?: false,
             local_inbox_snapshot_id: :default
           ]

    assert Enum.any?(profile.operator_notes, &String.contains?(&1, "memory-only"))
    assert Enum.any?(profile.unsupported_claims, &String.contains?(&1, "delivery guarantees"))
    assert :ok = LocalInboxPersistenceProfile.validate(profile)
  end

  test "opt-in durable profile exposes session options and save triggers" do
    profile = LocalInboxPersistenceProfile.opt_in_durable(snapshot_id: "operator-a")

    assert profile.mode == :opt_in_durable
    assert profile.enabled?
    assert profile.restore_on_start?
    assert :received_full_message in profile.save_triggers
    assert :received_message_beacon in profile.save_triggers
    assert :session_stop in profile.save_triggers

    assert LocalInboxPersistenceProfile.session_options(profile) == [
             persist_local_inbox?: true,
             restore_local_inbox?: true,
             local_inbox_snapshot_id: "operator-a"
           ]

    refute profile.cleanup.scheduled?
    assert profile.cleanup.operator_command =~ "prune_expired"
    assert Enum.any?(profile.operator_notes, &String.contains?(&1, "policy-approved"))
    assert :ok = LocalInboxPersistenceProfile.validate(profile)
  end

  test "restore can be disabled without disabling durable saves" do
    profile =
      LocalInboxPersistenceProfile.opt_in_durable(
        snapshot_id: :field_test,
        restore_on_start?: false
      )

    assert profile.enabled?
    refute profile.restore_on_start?

    assert profile.session_options == [
             persist_local_inbox?: true,
             restore_local_inbox?: false,
             local_inbox_snapshot_id: :field_test
           ]
  end

  test "custom persistence policy is carried without weakening validation" do
    assert {:ok, policy} =
             LocalInboxPersistencePolicy.new(
               full_message_retention_ms: :forever,
               beacon_ref_retention_ms: 1_000
             )

    profile = LocalInboxPersistenceProfile.opt_in_durable(policy: policy)

    assert profile.policy == policy
    assert :ok = LocalInboxPersistenceProfile.validate(profile)
  end

  test "invalid profiles fail closed" do
    assert {:error, :invalid_mode} =
             LocalInboxPersistenceProfile.validate(%{
               LocalInboxPersistenceProfile.memory_only()
               | mode: :always_on
             })

    assert {:error, :invalid_snapshot_id} =
             LocalInboxPersistenceProfile.validate(%{
               LocalInboxPersistenceProfile.memory_only()
               | snapshot_id: 123
             })

    assert {:error, :invalid_policy} =
             LocalInboxPersistenceProfile.validate(%{
               LocalInboxPersistenceProfile.memory_only()
               | policy: %{}
             })
  end
end
