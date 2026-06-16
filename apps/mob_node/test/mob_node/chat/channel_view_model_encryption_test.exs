defmodule Mob.Node.Chat.ChannelViewModelEncryptionTest do
  use ExUnit.Case, async: true

  alias Mob.Node.Chat.{ChannelViewModel, Composer}

  @identity %{peer_id: "alice-peer", nickname: "Alice"}
  @channel "#general"

  # Build an inbound encrypted (CHATG) packet carrying `blob` at `generation`.
  defp encrypted_packet(blob, generation) do
    {:ok, packet, _id} =
      Composer.build_packet(@channel, "ignored",
        identity: @identity,
        now_ms: 1_700_000_000_000,
        encryptor: fn _ch, _t -> {:ok, generation, blob} end
      )

    packet
  end

  defp deliver(pid, packet) do
    send(pid, {:mob_runtime, :packet, :test, "peer", packet})
    # bounce a synchronous call so the cast/info is processed before we read
    ChannelViewModel.snapshot(pid)
  end

  test "an encrypted message decrypts to plaintext when the key is present" do
    blob = :crypto.strong_rand_bytes(24)

    decryptor = fn @channel, "alice-peer", 5, ^blob -> {:ok, "decrypted body"} end

    {:ok, pid} = ChannelViewModel.start_link(channel: @channel, router: nil, decryptor: decryptor)
    snapshot = deliver(pid, encrypted_packet(blob, 5))

    assert [%{body: "decrypted body", locked: false, direction: :in}] = snapshot.messages
  end

  test "a message with no available key is surfaced as locked, not dropped" do
    decryptor = fn _ch, _sender, _gen, _blob -> {:error, :no_sender} end

    {:ok, pid} = ChannelViewModel.start_link(channel: @channel, router: nil, decryptor: decryptor)
    snapshot = deliver(pid, encrypted_packet("blob", 0))

    assert [%{locked: true, body: "", direction: :in}] = snapshot.messages
  end

  test "cleartext messages remain unlocked and need no decryptor" do
    {:ok, packet, _id} =
      Composer.build_packet(@channel, "plain hi", identity: @identity, now_ms: 1)

    decryptor = fn _, _, _, _ -> flunk("decryptor must not run for cleartext") end

    {:ok, pid} = ChannelViewModel.start_link(channel: @channel, router: nil, decryptor: decryptor)
    snapshot = deliver(pid, packet)

    assert [%{body: "plain hi", locked: false}] = snapshot.messages
  end
end
