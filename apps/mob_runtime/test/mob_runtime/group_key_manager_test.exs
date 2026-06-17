defmodule Mob.Runtime.GroupKeyManagerTest do
  use ExUnit.Case, async: false

  alias Mob.Runtime.{GroupKeyControl, GroupKeyManager}

  # Two independent in-memory stores so two managers (alice/bob) don't
  # share channel state. Each wraps its own ETS table.
  defmodule StoreA do
    @t :gkm_store_a
    def reset, do: reset_table(@t)
    def get(ch), do: fetch(@t, ch)
    def put(ch, v), do: insert(@t, ch, v)
    defp reset_table(t), do: Mob.Runtime.GroupKeyManagerTest.reset_table(t)
    defp fetch(t, ch), do: Mob.Runtime.GroupKeyManagerTest.fetch(t, ch)
    defp insert(t, ch, v), do: Mob.Runtime.GroupKeyManagerTest.insert(t, ch, v)
  end

  defmodule StoreB do
    @t :gkm_store_b
    def reset, do: Mob.Runtime.GroupKeyManagerTest.reset_table(@t)
    def get(ch), do: Mob.Runtime.GroupKeyManagerTest.fetch(@t, ch)
    def put(ch, v), do: Mob.Runtime.GroupKeyManagerTest.insert(@t, ch, v)
  end

  @doc false
  def reset_table(t) do
    if :ets.whereis(t) == :undefined, do: :ets.new(t, [:named_table, :public, :set])
    :ets.delete_all_objects(t)
    :ok
  end

  @doc false
  def fetch(t, ch) do
    case :ets.lookup(t, ch) do
      [{^ch, v}] -> v
      [] -> nil
    end
  end

  @doc false
  def insert(t, ch, v) do
    :ets.insert(t, {ch, v})
    :ok
  end

  @alice_id :binary.copy(<<0xAA>>, 32)
  @bob_id :binary.copy(<<0xBB>>, 32)
  @channel "#general"

  setup do
    StoreA.reset()
    StoreB.reset()

    # start_supervised! deterministically terminates each manager before
    # the next test, so the fixed registered names can't collide across
    # tests (a manual start_link + on_exit cleanup raced under --cover).
    alice =
      start_supervised!(
        {GroupKeyManager, name: :gkm_alice, store: StoreA, local_sender_id: @alice_id},
        id: :gkm_alice
      )

    bob =
      start_supervised!(
        {GroupKeyManager, name: :gkm_bob, store: StoreB, local_sender_id: @bob_id},
        id: :gkm_bob
      )

    %{alice: alice, bob: bob}
  end

  test "ensure_channel enables encryption and returns a usable SKDM", %{alice: alice} do
    refute GroupKeyManager.encrypted?(alice, @channel)
    assert {:ok, skdm} = GroupKeyManager.ensure_channel(alice, @channel)
    assert byte_size(skdm) == Mob.Noise.SenderKeyDistribution.encoded_size()
    assert GroupKeyManager.encrypted?(alice, @channel)
  end

  test "alice and bob exchange keys and read each other", %{alice: alice, bob: bob} do
    {:ok, alice_skdm} = GroupKeyManager.ensure_channel(alice, @channel)
    {:ok, bob_skdm} = GroupKeyManager.ensure_channel(bob, @channel)

    :ok = GroupKeyManager.install_remote(bob, @channel, @alice_id, alice_skdm)
    :ok = GroupKeyManager.install_remote(alice, @channel, @bob_id, bob_skdm)

    {:ok, gen, blob} = GroupKeyManager.encrypt(alice, @channel, "hi bob")
    assert {:ok, "hi bob"} = GroupKeyManager.decrypt(bob, @channel, @alice_id, gen, blob)

    {:ok, gen2, blob2} = GroupKeyManager.encrypt(bob, @channel, "hi alice")
    assert {:ok, "hi alice"} = GroupKeyManager.decrypt(alice, @channel, @bob_id, gen2, blob2)
  end

  test "decrypt before installing the sender key reports :no_sender", %{bob: bob} do
    assert {:error, :no_sender} = GroupKeyManager.decrypt(bob, @channel, @alice_id, 0, "blob")
  end

  test "encrypt auto-enables and advances the persisted generation", %{alice: alice} do
    {:ok, 0, _} = GroupKeyManager.encrypt(alice, @channel, "one")
    {:ok, 1, _} = GroupKeyManager.encrypt(alice, @channel, "two")
    {:ok, 2, _} = GroupKeyManager.encrypt(alice, @channel, "three")
  end

  test "handle_control :distribution installs the sender's key", %{alice: alice, bob: bob} do
    {:ok, alice_skdm} = GroupKeyManager.ensure_channel(alice, @channel)
    control = {:distribution, @channel, alice_skdm}

    assert :ok = GroupKeyManager.handle_control(bob, {control, @alice_id})

    {:ok, gen, blob} = GroupKeyManager.encrypt(alice, @channel, "via control")
    assert {:ok, "via control"} = GroupKeyManager.decrypt(bob, @channel, @alice_id, gen, blob)
  end

  test "handle_control :request for own key replies with our SKDM", %{alice: alice} do
    {:ok, alice_skdm} = GroupKeyManager.ensure_channel(alice, @channel)
    request = {:request, @channel, @alice_id}

    assert {:reply, ^alice_skdm} = GroupKeyManager.handle_control(alice, {request, @bob_id})
  end

  test "handle_control :request for another node's key is a no-op", %{alice: alice} do
    {:ok, _} = GroupKeyManager.ensure_channel(alice, @channel)
    request = {:request, @channel, @bob_id}
    assert :ok = GroupKeyManager.handle_control(alice, {request, @bob_id})
  end

  test "full control round-trip: a late joiner reads from the next message, not history",
       %{alice: alice, bob: bob} do
    {:ok, _} = GroupKeyManager.ensure_channel(alice, @channel)

    # Bob has no key yet, so this early message is unreadable to him.
    {:ok, gen0, blob0} = GroupKeyManager.encrypt(alice, @channel, "before-bob")
    assert {:error, :no_sender} = GroupKeyManager.decrypt(bob, @channel, @alice_id, gen0, blob0)

    # Bob requests alice's key; alice answers with her CURRENT chain;
    # bob installs it.
    req = GroupKeyControl.request(@channel, @alice_id)
    {:ok, decoded} = GroupKeyControl.decode(req)
    {:reply, skdm} = GroupKeyManager.handle_control(alice, {decoded, @bob_id})
    {:ok, dist_decoded} = GroupKeyControl.decode(GroupKeyControl.distribution(@channel, skdm))
    :ok = GroupKeyManager.handle_control(bob, {dist_decoded, @alice_id})

    # The message that predates bob's key stays unreadable (no history
    # backfill — this is the chosen forward-secrecy property).
    assert {:error, :duplicate_or_old} =
             GroupKeyManager.decrypt(bob, @channel, @alice_id, gen0, blob0)

    # But the next message alice sends decrypts cleanly.
    {:ok, gen1, blob1} = GroupKeyManager.encrypt(alice, @channel, "after-bob")
    assert {:ok, "after-bob"} = GroupKeyManager.decrypt(bob, @channel, @alice_id, gen1, blob1)
  end
end
