defmodule Mob.Noise.GroupSessionTest do
  use ExUnit.Case, async: true

  alias Mob.Noise.{GroupSession, SenderKeyDistribution}

  @alice "alice-peer-id"
  @bob "bob-peer-id"
  @aad "channel:#general"

  # Helper: install the SKDM produced by `from_session` (owned by
  # `sender_id`) into `into_session` so it can decrypt that sender.
  defp share_key(into_session, sender_id, skdm) do
    {:ok, decoded} = SenderKeyDistribution.decode(skdm)
    {:ok, session} = GroupSession.install_sender_key(into_session, sender_id, decoded)
    session
  end

  test "two members exchange sender keys and read each other's messages" do
    {alice, alice_skdm} = GroupSession.new() |> GroupSession.ensure_sending()
    {bob, bob_skdm} = GroupSession.new() |> GroupSession.ensure_sending()

    # Distribute keys over (a notional) pairwise channel.
    alice = share_key(alice, @bob, bob_skdm)
    bob = share_key(bob, @alice, alice_skdm)

    {:ok, alice, gen, blob} = GroupSession.encrypt(alice, "hi from alice", @aad)
    assert {:ok, _bob, "hi from alice"} = GroupSession.decrypt(bob, @alice, gen, blob, @aad)

    {:ok, _bob, gen2, blob2} = GroupSession.encrypt(bob, "hi from bob", @aad)
    assert {:ok, _alice, "hi from bob"} = GroupSession.decrypt(alice, @bob, gen2, blob2, @aad)
  end

  test "encrypt before ensure_sending fails" do
    assert {:error, :no_sending_chain} = GroupSession.encrypt(GroupSession.new(), "x", @aad)
  end

  test "decrypt from an unknown sender asks for its key" do
    {bob, _} = GroupSession.new() |> GroupSession.ensure_sending()
    assert {:error, :no_sender} = GroupSession.decrypt(bob, @alice, 0, "blob", @aad)
  end

  test "in-order stream decrypts sequentially" do
    {alice, skdm} = GroupSession.new() |> GroupSession.ensure_sending()
    bob = share_key(GroupSession.new(), @alice, skdm)

    {frames, _alice} =
      Enum.map_reduce(1..5, alice, fn i, a ->
        {:ok, a, gen, blob} = GroupSession.encrypt(a, "msg #{i}", @aad)
        {{gen, blob, "msg #{i}"}, a}
      end)

    Enum.reduce(frames, bob, fn {gen, blob, expected}, b ->
      assert {:ok, b2, ^expected} = GroupSession.decrypt(b, @alice, gen, blob, @aad)
      b2
    end)
  end

  test "out-of-order delivery: later generation arrives first, earlier still decrypts" do
    {alice, skdm} = GroupSession.new() |> GroupSession.ensure_sending()
    bob = share_key(GroupSession.new(), @alice, skdm)

    {:ok, alice, g0, b0} = GroupSession.encrypt(alice, "first", @aad)
    {:ok, alice, g1, b1} = GroupSession.encrypt(alice, "second", @aad)
    {:ok, _alice, g2, b2} = GroupSession.encrypt(alice, "third", @aad)

    # Receive 3rd, then 1st, then 2nd.
    {:ok, bob, "third"} = GroupSession.decrypt(bob, @alice, g2, b2, @aad)
    {:ok, bob, "first"} = GroupSession.decrypt(bob, @alice, g0, b0, @aad)
    assert {:ok, _bob, "second"} = GroupSession.decrypt(bob, @alice, g1, b1, @aad)
  end

  test "replay of an already-consumed generation is rejected" do
    {alice, skdm} = GroupSession.new() |> GroupSession.ensure_sending()
    bob = share_key(GroupSession.new(), @alice, skdm)

    {:ok, _alice, gen, blob} = GroupSession.encrypt(alice, "once", @aad)
    {:ok, bob, "once"} = GroupSession.decrypt(bob, @alice, gen, blob, @aad)

    assert {:error, :duplicate_or_old} = GroupSession.decrypt(bob, @alice, gen, blob, @aad)
  end

  test "replay of a cached skipped generation is rejected after first use" do
    {alice, skdm} = GroupSession.new() |> GroupSession.ensure_sending()
    bob = share_key(GroupSession.new(), @alice, skdm)

    {:ok, alice, g0, b0} = GroupSession.encrypt(alice, "a", @aad)
    {:ok, _alice, g1, b1} = GroupSession.encrypt(alice, "b", @aad)

    # Jump ahead to g1, caching g0; then consume g0; then replay g0.
    {:ok, bob, "b"} = GroupSession.decrypt(bob, @alice, g1, b1, @aad)
    {:ok, bob, "a"} = GroupSession.decrypt(bob, @alice, g0, b0, @aad)
    assert {:error, :duplicate_or_old} = GroupSession.decrypt(bob, @alice, g0, b0, @aad)
  end

  test "a generation beyond max_skip is rejected without advancing the chain" do
    {alice, skdm} = GroupSession.new() |> GroupSession.ensure_sending()
    bob = share_key(GroupSession.new(max_skip: 10), @alice, skdm)

    _ = alice
    # Forge a far-future generation; the blob need not be valid — the
    # too-far-ahead guard fires before any AEAD work.
    assert {:error, :too_far_ahead} = GroupSession.decrypt(bob, @alice, 11, "forged", @aad)

    # Chain is untouched, so a legitimate gen-0 message still decrypts.
    {:ok, _alice, g0, b0} = GroupSession.encrypt(alice, "real", @aad)
    assert {:ok, _bob, "real"} = GroupSession.decrypt(bob, @alice, g0, b0, @aad)
  end

  test "wrong aad on receive fails authentication" do
    {alice, skdm} = GroupSession.new() |> GroupSession.ensure_sending()
    bob = share_key(GroupSession.new(), @alice, skdm)

    {:ok, _alice, gen, blob} = GroupSession.encrypt(alice, "secret", @aad)
    assert {:error, :auth_failed} = GroupSession.decrypt(bob, @alice, gen, blob, "channel:#other")
  end

  test "rotate_sending breaks old receivers until they install the new key" do
    {alice, skdm1} = GroupSession.new() |> GroupSession.ensure_sending()
    bob = share_key(GroupSession.new(), @alice, skdm1)

    {alice, skdm2} = GroupSession.rotate_sending(alice)
    {:ok, _alice, gen, blob} = GroupSession.encrypt(alice, "post-rotation", @aad)

    # Bob's old chain can't decrypt the new chain's message.
    assert {:error, _} = GroupSession.decrypt(bob, @alice, gen, blob, @aad)

    # After installing the new SKDM, it works.
    bob = share_key(bob, @alice, skdm2)
    assert {:ok, _bob, "post-rotation"} = GroupSession.decrypt(bob, @alice, gen, blob, @aad)
  end

  test "has_sender? reflects installed receiving chains" do
    {_, skdm} = GroupSession.new() |> GroupSession.ensure_sending()
    session = GroupSession.new()
    refute GroupSession.has_sender?(session, @alice)
    session = share_key(session, @alice, skdm)
    assert GroupSession.has_sender?(session, @alice)
  end
end
