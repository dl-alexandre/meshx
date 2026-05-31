defmodule Mob.Store.IdentityTrustTest do
  use ExUnit.Case

  alias Mob.Store.{Identity, Trust}

  setup do
    Mob.Store.TestHelpers.ensure_db_started()
    Identity.clear()
    Trust.clear()

    original_policy = Application.get_env(:mob_store, :trust_policy)

    on_exit(fn ->
      Application.put_env(:mob_store, :trust_policy, original_policy)
    end)

    :ok
  end

  test "local identity persists and exposes Noise static keys" do
    assert {:ok, identity} = Identity.ensure_local()
    assert byte_size(identity.public_key) == 32
    assert byte_size(identity.private_key) == 32

    assert {:ok, %{s: {public_key, private_key}}} = Identity.static_keys()
    assert public_key == identity.public_key
    assert private_key == identity.private_key

    assert {:ok, same_identity} = Identity.ensure_local()
    assert same_identity.public_key == identity.public_key

    assert {:ok, peer_id} = Identity.local_peer_id()
    assert peer_id == Base.url_encode64(identity.public_key, padding: false)
  end

  test "tofu policy pins first seen key and rejects key changes" do
    Application.put_env(:mob_store, :trust_policy, :tofu)

    key = :crypto.strong_rand_bytes(32)
    changed_key = :crypto.strong_rand_bytes(32)

    assert :ok = Trust.authorize("peer-a", key)
    assert Trust.trusted?("peer-a", key)
    assert :ok = Trust.authorize("peer-a", key)
    assert {:error, :key_mismatch} = Trust.authorize("peer-a", changed_key)
  end

  test "pinned and allowlist policies require pre-pinned keys" do
    key = :crypto.strong_rand_bytes(32)
    changed_key = :crypto.strong_rand_bytes(32)

    assert {:error, :untrusted_peer} = Trust.authorize("peer-a", key, policy: :pinned)
    assert {:error, :untrusted_peer} = Trust.authorize("peer-a", key, policy: :allowlist)

    assert {:ok, _peer} = Trust.pin("peer-a", key)
    assert :ok = Trust.authorize("peer-a", key, policy: :pinned)
    assert {:error, :key_mismatch} = Trust.authorize("peer-a", changed_key, policy: :pinned)
  end

  test "blocked peers are rejected" do
    key = :crypto.strong_rand_bytes(32)

    assert {:ok, _peer} = Trust.pin("peer-a", key)
    assert {:ok, _peer} = Trust.block("peer-a")
    assert {:error, :blocked} = Trust.authorize("peer-a", key)
  end

  test "trust records can be replaced, fetched, and cleared" do
    key = :crypto.strong_rand_bytes(32)
    replacement = :crypto.strong_rand_bytes(32)

    refute Trust.trusted?("peer-a", key)
    assert {:error, :not_found} = Trust.block("peer-a")

    assert {:ok, _peer} = Trust.pin("peer-a", key)
    assert %{public_key: ^key} = Trust.get("peer-a")

    assert {:ok, _peer} = Trust.pin("peer-a", replacement)
    assert Trust.trusted?("peer-a", replacement)
    refute Trust.trusted?("peer-a", key)

    assert :ok = Trust.clear()
    assert Trust.get("peer-a") == nil
  end
end
