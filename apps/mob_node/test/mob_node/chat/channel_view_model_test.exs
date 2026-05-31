defmodule Mob.Node.Chat.ChannelViewModelTest do
  use ExUnit.Case, async: false

  alias Mob.Node.Chat.{ChannelViewModel, Composer}
  alias Mob.Node.Chat.ChannelViewModel.Message

  @identity %{peer_id: "alice-peer", nickname: "Alice"}
  @now 1_700_000_000_000

  defmodule FakeRouter do
    @moduledoc false
    def subscribe(_pid, _opts), do: :ok
    def broadcast_packet(packet), do: send(self(), {:fake_router_sent, packet}) && :ok
  end

  defp start_vm(opts \\ []) do
    opts = Keyword.merge([channel: "#general", router: nil], opts)
    start_supervised!({ChannelViewModel, opts})
  end

  defp incoming_for(channel, text, sender) do
    {:ok, packet, _msg_id} =
      Composer.build_packet(channel, text,
        identity: %{peer_id: sender, nickname: sender},
        now_ms: @now
      )

    {:mob_runtime, :packet, :ble, sender, packet}
  end

  describe "snapshot/1" do
    test "starts empty with the configured channel" do
      vm = start_vm()
      snapshot = ChannelViewModel.snapshot(vm)
      assert snapshot.channel == "#general"
      assert snapshot.messages == []
      assert snapshot.message_count == 0
    end
  end

  describe "inbound CHAT packets" do
    test "appended when channel_id matches" do
      vm = start_vm()
      send(vm, incoming_for("#general", "hello", "bob-peer"))
      # round-trip a call to flush handle_info
      _ = ChannelViewModel.snapshot(vm)

      assert %{messages: [msg], message_count: 1} = ChannelViewModel.snapshot(vm)

      assert %Message{
               direction: :in,
               status: :delivered,
               body: "hello",
               sender_peer_id: "bob-peer"
             } = msg
    end

    test "ignored when channel_id mismatches (router shouldn't even deliver, defensive)" do
      vm = start_vm()
      send(vm, incoming_for("#other", "hello", "bob-peer"))
      _ = ChannelViewModel.snapshot(vm)
      assert %{messages: [], message_count: 0} = ChannelViewModel.snapshot(vm)
    end

    test "preserves insertion order across multiple inbounds" do
      vm = start_vm()
      send(vm, incoming_for("#general", "first", "bob-peer"))
      send(vm, incoming_for("#general", "second", "carol-peer"))
      send(vm, incoming_for("#general", "third", "bob-peer"))
      _ = ChannelViewModel.snapshot(vm)

      assert %{messages: [m1, m2, m3]} = ChannelViewModel.snapshot(vm)
      assert {m1.body, m2.body, m3.body} == {"first", "second", "third"}
    end
  end

  describe "subscribe/2" do
    test "delivers the initial snapshot synchronously and pushes updates on change" do
      vm = start_vm()
      assert {:ok, %{message_count: 0}} = ChannelViewModel.subscribe(vm)

      send(vm, incoming_for("#general", "pushed", "bob-peer"))

      assert_receive {ChannelViewModel, :updated,
                      %{message_count: 1, messages: [%{body: "pushed"}]}}
    end
  end

  describe "send_text/2 via FakeRouter" do
    setup do
      # Composer + ChannelViewModel.local_sender both reach into
      # Mob.Store.Identity, so start the store DB for this group.
      Application.ensure_all_started(:mob_store)
      ensure_db_started()
      :ok
    end

    test "dispatches via router and appends an outbound :pending entry" do
      vm = start_vm(router: FakeRouter)
      assert {:ok, message_id} = ChannelViewModel.send_text(vm, "hi there")
      assert is_binary(message_id) and byte_size(message_id) == 16

      _ = ChannelViewModel.snapshot(vm)

      assert %{messages: [%Message{direction: :out, status: :pending, body: "hi there"}]} =
               ChannelViewModel.snapshot(vm)
    end

    defp ensure_db_started do
      case Mob.Store.DB.start_link([]) do
        {:ok, pid} ->
          Process.unlink(pid)
          :ok

        {:error, {:already_started, _pid}} ->
          :ok
      end
    end
  end

  describe "maybe_chat_message/2 (pure helper)" do
    test "skips non-CHAT envelopes on the same channel" do
      # synthesize a packet whose envelope payload_type isn't CHAT
      alias Mob.Node.BLE.MessageEnvelope
      alias Mob.Protocol.Packet

      {:ok, envelope} =
        MessageEnvelope.build(
          sender_peer_id: "x",
          created_at: 0,
          payload_type: "OTHER",
          payload: "nope"
        )

      packet = %Packet{
        type: :data,
        msg_id: 1,
        payload: MessageEnvelope.encode(envelope),
        channel_id: "#general"
      }

      assert :skip = ChannelViewModel.maybe_chat_message(packet, "#general")
    end
  end
end
