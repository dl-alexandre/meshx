defmodule MeshxRuntime.RouterTest do
  use ExUnit.Case

  @moduletag capture_log: true

  alias MeshxProtocol.{Ack, Codec, Fragment, Packet}
  alias MeshxRuntime.{FragmentBuffer, Outbox, PeerRegistry, Router, SessionManager}
  alias MeshxStore.{Dedupe, Identity, RelayCache, Trust}
  alias MeshxStore.Outbox, as: StoreOutbox
  alias MeshxTransport.{Memory, Memory.Hub, Peer}

  defmodule FailingAdapter do
    @behaviour MeshxTransport

    @impl true
    def send_frame(_transport, _peer_id, _frame, _opts), do: {:error, :send_failed}

    @impl true
    def broadcast_frame(_transport, _frame, _opts), do: {:error, :broadcast_failed}

    @impl true
    def peers(_transport), do: []
  end

  setup do
    restart_runtime()
    Router.reset()
    Outbox.reset()
    SessionManager.reset()
    FragmentBuffer.reset()
    PeerRegistry.reset()
    Hub.reset()
    Identity.clear()
    Trust.clear()
    Dedupe.clear()
    RelayCache.clear()
    StoreOutbox.clear()
    Router.subscribe(self())

    {:ok, local} = Memory.start_link(id: "local", event_target: Router)
    :ok = Router.attach_transport(:memory, Memory, local)
    {:ok, remote} = Memory.start_link(id: "remote", event_target: self())

    assert_receive {:meshx_runtime, :peer_up, :memory, %{id: "remote"}}

    %{local: local, remote: remote}
  end

  test "records peer discovery in the peer registry" do
    assert %{id: "remote", transport: :memory} = PeerRegistry.get("remote")
    assert [%{id: "remote"}] = PeerRegistry.list()
  end

  test "decodes inbound frames, dedupes, stores relay payloads, and emits packet events", %{
    remote: remote
  } do
    flush_transport_events()
    id = msg_id()
    packet = Packet.new(:data, id, "hello-router")
    {:ok, frame} = Codec.encode_packet(packet)

    assert :ok = Memory.send_frame(remote, "local", frame)
    assert_receive {:meshx_runtime, :packet, :memory, "remote", received}

    assert received.msg_id == id
    assert received.payload == "hello-router"
    assert Dedupe.seen?(id)
    assert RelayCache.get(id) == {id, "hello-router", 0}
  end

  test "drops duplicate inbound frames", %{remote: remote} do
    flush_transport_events()
    id = msg_id()
    packet = Packet.new(:data, id, "dup")
    {:ok, frame} = Codec.encode_packet(packet)

    assert :ok = Memory.send_frame(remote, "local", frame)
    assert_receive {:meshx_runtime, :packet, :memory, "remote", _packet}

    assert :ok = Memory.send_frame(remote, "local", frame)
    assert_receive {:meshx_runtime, :duplicate, :memory, "remote", ^id}
    refute_receive {:meshx_runtime, :packet, :memory, "remote", _packet}
  end

  test "broadcasts outbound packets through attached transports" do
    flush_transport_events()
    packet = Packet.new(:data, msg_id(), "outbound")

    assert :ok = Router.broadcast_packet(packet)
    assert_receive {:meshx_transport, :memory, {:frame, "local", frame}}
    assert {:ok, decoded, <<>>} = Codec.decode_packet(frame)
    assert decoded.payload == "outbound"
  end

  test "sends direct packets to a discovered peer" do
    attach_telemetry([
      [:meshx_runtime, :router, :send, :start],
      [:meshx_runtime, :router, :send, :stop]
    ])

    flush_transport_events()
    packet = Packet.new(:data, msg_id(), "direct")

    assert :ok = Router.send_packet("remote", packet)
    assert_receive {:meshx_transport, :memory, {:frame, "local", frame}}
    assert {:ok, decoded, <<>>} = Codec.decode_packet(frame)
    assert decoded.payload == "direct"

    assert_receive {:telemetry, [:meshx_runtime, :router, :send, :start], %{frames: 1},
                    %{peer_id: "remote"}}

    assert_receive {:telemetry, [:meshx_runtime, :router, :send, :stop], %{frames: 1},
                    %{peer_id: "remote"}}
  end

  test "detach_transport reports unavailable transport paths" do
    flush_transport_events()
    packet = Packet.new(:data, msg_id(), "detached")

    assert :ok = Router.detach_transport(:memory)
    assert {:error, :transport_not_attached} = Router.send_packet("remote", packet)

    assert {:error, :transport_not_attached} =
             Router.send_packet("remote", packet, transport: :memory)
  end

  test "invalid transport options fall back to discovered peer transport" do
    flush_transport_events()
    packet = Packet.new(:data, msg_id(), "fallback-transport")

    assert :ok = Router.send_packet("remote", packet, transport: "not-an-atom")
    assert_receive {:meshx_transport, :memory, {:frame, "local", frame}}
    assert {:ok, decoded, <<>>} = Codec.decode_packet(frame)
    assert decoded.payload == "fallback-transport"
  end

  test "unsubscribe suppresses runtime notifications while peer registry still updates", %{
    remote: remote
  } do
    flush_transport_events()

    assert :ok = Router.unsubscribe()
    GenServer.stop(remote)

    assert_eventually(fn -> PeerRegistry.get("remote") == nil end)
    refute_receive {:meshx_runtime, :peer_down, :memory, "remote"}, 25
  end

  test "emits decode errors for invalid inbound frames", %{remote: remote} do
    attach_telemetry([[:meshx_runtime, :router, :frame, :decode_error]])
    flush_transport_events()

    assert :ok = Memory.send_frame(remote, "local", "not-a-packet")
    assert_receive {:meshx_runtime, :decode_error, :memory, "remote", _reason}

    assert_receive {:telemetry, [:meshx_runtime, :router, :frame, :decode_error], %{count: 1},
                    %{transport: :memory, peer_id: "remote"}}
  end

  test "emits ack errors for malformed ack packets", %{remote: remote} do
    attach_telemetry([[:meshx_runtime, :router, :ack, :error]])
    flush_transport_events()
    packet = Packet.new(:ack, msg_id(), "bad")
    {:ok, frame} = Codec.encode_packet(packet)

    assert :ok = Memory.send_frame(remote, "local", frame)
    assert_receive {:meshx_runtime, :ack_error, :memory, "remote", :malformed_ack}

    assert_receive {:telemetry, [:meshx_runtime, :router, :ack, :error], %{count: 1},
                    %{reason: :malformed_ack}}
  end

  test "emits fragment errors for malformed fragment packets", %{remote: remote} do
    attach_telemetry([[:meshx_runtime, :router, :fragment, :error]])
    flush_transport_events()
    packet = Packet.new(:fragment, msg_id(), <<1, 2, 3>>)
    {:ok, frame} = Codec.encode_packet(packet)

    assert :ok = Memory.send_frame(remote, "local", frame)
    assert_receive {:meshx_runtime, :fragment_error, :memory, "remote", :malformed_fragment}

    assert_receive {:telemetry, [:meshx_runtime, :router, :fragment, :error], %{count: 1},
                    %{reason: :malformed_fragment}}
  end

  test "emits decode errors for reassembled invalid frames", %{remote: remote} do
    flush_transport_events()
    original_id = msg_id()

    fragment =
      Packet.new(:fragment, msg_id(), <<original_id::32-little, 0::8, 1::8, "bad-frame">>)

    {:ok, frame} = Codec.encode_packet(fragment)

    assert :ok = Memory.send_frame(remote, "local", frame)
    assert_receive {:meshx_runtime, :fragments_complete, :memory, "remote", ^original_id}
    assert_receive {:meshx_runtime, :decode_error, :memory, "remote", _reason}
  end

  test "emits decrypt errors for encrypted packets without sessions", %{remote: remote} do
    attach_telemetry([[:meshx_runtime, :router, :packet, :decrypt_error]])
    flush_transport_events()

    encrypted = %{
      Packet.new(:data, msg_id(), "ciphertext")
      | flags: Packet.flag_encrypted()
    }

    {:ok, frame} = Codec.encode_packet(encrypted)
    assert :ok = Memory.send_frame(remote, "local", frame)

    assert_receive {:meshx_runtime, :decrypt_error, :memory, "remote", :session_not_found}

    assert_receive {:telemetry, [:meshx_runtime, :router, :packet, :decrypt_error], %{count: 1},
                    %{reason: :session_not_found}}
  end

  test "control packets without handshake payload are delivered as application packets", %{
    remote: remote
  } do
    attach_telemetry([[:meshx_runtime, :router, :packet, :delivered]])
    flush_transport_events()
    id = msg_id()
    packet = Packet.new(:control, id, "plain-control")
    {:ok, frame} = Codec.encode_packet(packet)

    assert :ok = Memory.send_frame(remote, "local", frame)

    assert_receive {:meshx_runtime, :packet, :memory, "remote", delivered}
    assert delivered.type == :control
    assert delivered.msg_id == id
    assert delivered.payload == "plain-control"

    assert_receive {:telemetry, [:meshx_runtime, :router, :packet, :delivered], %{count: 1},
                    %{msg_id: ^id, type: :control}}
  end

  test "ttl-one packets are delivered but not relayed", %{remote: remote} do
    {:ok, _relay_target} = Memory.start_link(id: "relay-target", event_target: self())
    flush_transport_events()

    packet = %{Packet.new(:data, msg_id(), "do-not-relay") | ttl: 1}
    {:ok, frame} = Codec.encode_packet(packet)

    assert :ok = Memory.send_frame(remote, "local", frame)
    assert_receive {:meshx_runtime, :packet, :memory, "remote", delivered}
    assert delivered.payload == "do-not-relay"
    refute_receive {:meshx_transport, :memory, {:frame, "local", _frame}}, 50
  end

  test "delivered ack-requested packets generate direct ACKs", %{remote: remote} do
    flush_transport_events()
    id = msg_id()
    packet = %{Packet.new(:data, id, "ack-me") | flags: Packet.flag_ack_requested()}
    {:ok, frame} = Codec.encode_packet(packet)

    assert :ok = Memory.send_frame(remote, "local", frame)

    assert_receive {:meshx_runtime, :packet, :memory, "remote", delivered}
    assert delivered.msg_id == id

    assert_receive {:meshx_transport, :memory, {:frame, "local", ack_frame}}
    assert_ack_frame(ack_frame, id)
  end

  test "per-peer backpressure queues ACK-tracked sends until ACK release" do
    attach_telemetry([
      [:meshx_runtime, :router, :backpressure, :queued],
      [:meshx_runtime, :router, :backpressure, :dropped],
      [:meshx_runtime, :router, :backpressure, :dequeued]
    ])

    flush_transport_events()

    packet1 = ack_packet("window-1")
    packet2 = ack_packet("window-2")
    packet3 = ack_packet("window-3")

    opts = [send_window: 1, queue_limit: 1]

    assert :ok = Router.send_packet("remote", packet1, opts)
    assert_receive {:meshx_transport, :memory, {:frame, "local", frame1}}, 2_000
    assert {:ok, decoded1, <<>>} = Codec.decode_packet(frame1)
    assert decoded1.payload == "window-1"

    assert {:queued, :backpressure, 1} = Router.send_packet("remote", packet2, opts)

    assert_receive {:telemetry, [:meshx_runtime, :router, :backpressure, :queued], %{depth: 1},
                    %{peer_id: "remote", msg_id: msg_id2}}

    assert msg_id2 == packet2.msg_id

    assert {:error, :backpressure_queue_full} = Router.send_packet("remote", packet3, opts)

    assert_receive {:telemetry, [:meshx_runtime, :router, :backpressure, :dropped], %{count: 1},
                    _}

    refute_receive {:meshx_transport, :memory, {:frame, "local", _frame}}, 25

    send_ack_from_peer("remote", packet1.msg_id)
    assert_receive {:meshx_runtime, :ack, :memory, "remote", acked_id, _result}
    assert acked_id == packet1.msg_id

    assert_receive {:meshx_transport, :memory, {:frame, "local", frame2}}
    assert {:ok, decoded2, <<>>} = Codec.decode_packet(frame2)
    assert decoded2.payload == "window-2"

    assert_receive {:telemetry, [:meshx_runtime, :router, :backpressure, :dequeued], %{count: 1},
                    %{peer_id: "remote", msg_id: msg_id2_again, result: :ok}}

    assert msg_id2_again == packet2.msg_id
  end

  test "queues packets for unknown peers and waits for ACK after replay" do
    flush_transport_events()
    packet = Packet.new(:data, msg_id(), "offline-direct")

    assert {:queued, :unknown_peer, queued} = Router.send_packet("later", packet, store: true)
    assert queued.status == :pending
    assert [pending] = StoreOutbox.pending_for_destination("later")
    assert pending.msg_id == packet.msg_id

    {:ok, _later} = Memory.start_link(id: "later", event_target: self())

    assert_receive {:meshx_runtime, :peer_up, :memory, %{id: "later"}}
    assert_receive {:meshx_transport, :memory, {:frame, "local", frame}}
    assert {:ok, decoded, <<>>} = Codec.decode_packet(frame)
    assert decoded.msg_id == packet.msg_id
    assert decoded.payload == "offline-direct"
    assert Packet.flag_set?(decoded.flags, Packet.flag_ack_requested())
    assert_eventually(fn -> hd(StoreOutbox.pending_for_destination("later")).attempts == 1 end)

    send_ack_from_peer("later", packet.msg_id)
    assert_receive {:meshx_runtime, :ack, :memory, "later", acked_id, {:ok, _record}}
    assert acked_id == packet.msg_id
    assert_eventually(fn -> StoreOutbox.pending_for_destination("later") == [] end)
  end

  test "outbox retries pending rows until ACK or max attempts" do
    flush_transport_events()
    packet = Packet.new(:data, msg_id(), "retry-me")

    assert {:queued, :unknown_peer, queued} =
             Router.send_packet("retry", packet, store: true, max_attempts: 2)

    {:ok, _retry} = Memory.start_link(id: "retry", event_target: self())

    assert_receive {:meshx_runtime, :peer_up, :memory, %{id: "retry"}}
    assert_receive {:meshx_transport, :memory, {:frame, "local", _frame1}}
    assert_eventually(fn -> StoreOutbox.get(queued.id).attempts == 1 end)

    Outbox.retry_now()
    assert_receive {:meshx_transport, :memory, {:frame, "local", _frame2}}
    assert_eventually(fn -> StoreOutbox.get(queued.id).status == :failed end)
  end

  test "fragments outbound packets when mtu requires it" do
    flush_transport_events()
    mtu = 70
    payload = :binary.copy("x", 220)
    packet = Packet.new(:data, msg_id(), payload)

    assert :ok = Router.send_packet("remote", packet, mtu: mtu)

    frames = collect_transport_frames()
    assert length(frames) > 1

    Enum.each(frames, fn frame ->
      assert byte_size(frame) <= mtu
      assert {:ok, fragment, <<>>} = Codec.decode_packet(frame)
      assert fragment.type == :fragment
    end)
  end

  test "returns mtu errors before sending oversized packets" do
    flush_transport_events()

    assert {:error, :mtu_too_small} =
             Router.send_packet("remote", Packet.new(:data, msg_id(), "too-small"), mtu: 18)

    assert {:error, :too_many_fragments} =
             Router.send_packet(
               "remote",
               Packet.new(:data, msg_id(), :binary.copy("x", 300)),
               mtu: 19
             )
  end

  test "returns broadcast encode errors" do
    bad_packet = %Packet{type: :bad_type, msg_id: msg_id(), payload: <<>>}

    assert {:error, _reason} = Router.broadcast_packet(bad_packet)
  end

  test "surfaces transport send and broadcast failures" do
    flush_transport_events()
    peer = Peer.new("failing", :failing)

    assert :ok = PeerRegistry.up(peer)
    assert :ok = Router.attach_transport(:failing, FailingAdapter, self())

    packet = Packet.new(:data, msg_id(), "will-fail")

    assert {:error, :send_failed} = Router.send_packet("failing", packet)
    assert {:error, results} = Router.broadcast_packet(packet)
    assert {:error, :broadcast_failed} in results
  end

  test "reports queueing errors when stored delivery cannot encode" do
    bad_packet = %Packet{type: :bad_type, msg_id: msg_id(), payload: <<>>}

    assert {:error, {_send_reason, _enqueue_reason}} =
             Router.send_packet("missing", bad_packet, store: true)
  end

  test "reassembles inbound fragments before packet delivery", %{remote: remote} do
    flush_transport_events()
    id = msg_id()
    payload = :binary.copy("large", 60)
    packet = Packet.new(:data, id, payload)
    {:ok, original_frame} = Codec.encode_packet(packet)

    frames =
      id
      |> Fragment.fragment(original_frame, max_chunk_size: 45)
      |> Enum.map(fn fragment ->
        {:ok, frame} = Codec.encode_packet(fragment)
        frame
      end)

    assert length(frames) > 1

    frames
    |> Enum.drop(-1)
    |> Enum.each(fn frame -> assert :ok = Memory.send_frame(remote, "local", frame) end)

    refute_receive {:meshx_runtime, :packet, :memory, "remote", _packet}, 25

    [last] = Enum.take(frames, -1)
    assert :ok = Memory.send_frame(remote, "local", last)

    assert_receive {:meshx_runtime, :fragments_complete, :memory, "remote", ^id}
    assert_receive {:meshx_runtime, :packet, :memory, "remote", reassembled}
    assert reassembled.msg_id == id
    assert reassembled.payload == payload
  end

  test "relays public packets only to relay-capable peers", %{remote: remote} do
    {:ok, _relay_yes} = Memory.start_link(id: "relay-yes", event_target: self())

    {:ok, _relay_no} =
      Memory.start_link(id: "relay-no", event_target: self(), capabilities: %{relay: false})

    flush_transport_events()

    packet = %{Packet.new(:data, msg_id(), "relay-me") | ttl: 3}
    {:ok, frame} = Codec.encode_packet(packet)

    assert :ok = Memory.send_frame(remote, "local", frame)
    assert_receive {:meshx_runtime, :packet, :memory, "remote", _packet}

    relayed_frames = collect_transport_frames()
    assert length(relayed_frames) == 1
    assert {:ok, relayed, <<>>} = Codec.decode_packet(hd(relayed_frames))
    assert relayed.payload == "relay-me"
    assert relayed.ttl == 2
  end

  test "secure direct sends require an established session" do
    flush_transport_events()
    packet = Packet.new(:data, msg_id(), "secret")

    assert {:error, :session_not_established} = Router.send_packet("remote", packet, secure: true)
  end

  test "peer capabilities can require secure sends" do
    {:ok, _secure} =
      Memory.start_link(
        id: "secure",
        event_target: self(),
        capabilities: %{secure_required: true}
      )

    assert_receive {:meshx_runtime, :peer_up, :memory, %{id: "secure"}}

    packet = Packet.new(:data, msg_id(), "must-encrypt")
    assert {:error, :secure_required} = Router.send_packet("secure", packet)
    assert {:error, :secure_required} = Router.send_packet("secure", packet, store: true)
    assert StoreOutbox.pending_for_destination("secure") == []
  end

  test "performs Noise handshake and encrypts direct packets", %{remote: remote} do
    flush_transport_events()
    {:ok, remote_session} = MeshxNoise.Session.start_link(role: :responder)

    assert :ok = Router.ensure_secure_session("remote")
    assert_receive {:meshx_transport, :memory, {:frame, "local", frame1}}
    msg1 = decode_handshake_frame(frame1)

    :ok = MeshxNoise.Session.handshake_recv(remote_session, msg1)
    {:ok, msg2} = MeshxNoise.Session.handshake_send(remote_session)
    send_handshake_from_remote(remote, msg2)

    assert_receive {:meshx_transport, :memory, {:frame, "local", frame3}}, 2_000
    msg3 = decode_handshake_frame(frame3)
    :ok = MeshxNoise.Session.handshake_recv(remote_session, msg3)

    assert_receive {:meshx_runtime, :noise_established, :memory, "remote"}, 2_000
    assert SessionManager.established?("remote")
    assert MeshxNoise.Session.established?(remote_session)
    assert Trust.trusted?("remote", SessionManager.remote_key("remote"))
    assert :ok = Router.ensure_secure_session("remote")

    packet = Packet.new(:data, msg_id(), "encrypted-direct")
    assert :ok = Router.send_packet("remote", packet, secure: true)
    assert_receive {:meshx_transport, :memory, {:frame, "local", encrypted_frame}}, 2_000
    assert {:ok, encrypted_packet, <<>>} = Codec.decode_packet(encrypted_frame)

    assert Packet.flag_set?(encrypted_packet.flags, Packet.flag_encrypted())
    refute encrypted_packet.payload == "encrypted-direct"

    assert {:ok, "encrypted-direct"} =
             MeshxNoise.Session.decrypt(remote_session, encrypted_packet.payload)
  end

  test "drops Noise session on peer_down so reconnect renegotiates", %{
    local: local,
    remote: remote
  } do
    flush_transport_events()
    {:ok, remote_session} = MeshxNoise.Session.start_link(role: :responder)
    establish_remote_session(remote, remote_session)

    assert SessionManager.established?("remote")

    GenServer.cast(local, {:peer_down, "remote"})
    assert_receive {:meshx_runtime, :peer_down, :memory, "remote"}, 1_000

    refute SessionManager.established?("remote")
    assert SessionManager.remote_key("remote") == nil
  end

  test "reports secure handshake already in progress" do
    flush_transport_events()

    assert :ok = Router.ensure_secure_session("remote")
    assert_receive {:meshx_transport, :memory, {:frame, "local", _frame1}}, 2_000
    assert {:error, :handshake_in_progress} = Router.ensure_secure_session("remote")
  end

  test "decrypts inbound encrypted packets", %{remote: remote} do
    flush_transport_events()
    {:ok, remote_session} = MeshxNoise.Session.start_link(role: :responder)
    establish_remote_session(remote, remote_session)

    id = msg_id()
    {:ok, ciphertext} = MeshxNoise.Session.encrypt(remote_session, "from-remote")

    encrypted = %{
      Packet.new(:data, id, IO.iodata_to_binary(ciphertext))
      | flags: Packet.flag_encrypted()
    }

    {:ok, frame} = Codec.encode_packet(encrypted)
    assert :ok = Memory.send_frame(remote, "local", frame)

    assert_receive {:meshx_runtime, :packet, :memory, "remote", packet}
    assert packet.msg_id == id
    assert packet.payload == "from-remote"
    refute Packet.flag_set?(packet.flags, Packet.flag_encrypted())
  end

  test "does not relay decrypted secure packets", %{remote: remote} do
    flush_transport_events()
    {:ok, _relay_target} = Memory.start_link(id: "relay-target", event_target: self())
    {:ok, remote_session} = MeshxNoise.Session.start_link(role: :responder)
    establish_remote_session(remote, remote_session)
    flush_transport_events()

    id = msg_id()
    {:ok, ciphertext} = MeshxNoise.Session.encrypt(remote_session, "private")

    encrypted = %{
      Packet.new(:data, id, IO.iodata_to_binary(ciphertext))
      | flags: Packet.flag_encrypted(),
        ttl: 3
    }

    {:ok, frame} = Codec.encode_packet(encrypted)
    assert :ok = Memory.send_frame(remote, "local", frame)

    assert_receive {:meshx_runtime, :packet, :memory, "remote", packet}
    assert packet.payload == "private"
    refute_receive {:meshx_transport, :memory, {:frame, "local", _frame}}, 50
  end

  defp msg_id do
    System.unique_integer([:positive]) |> rem(4_000_000_000)
  end

  defp ack_packet(payload) do
    %{Packet.new(:data, msg_id(), payload) | flags: Packet.flag_ack_requested()}
  end

  defp establish_remote_session(remote, remote_session) do
    assert :ok = Router.ensure_secure_session("remote")
    assert_receive {:meshx_transport, :memory, {:frame, "local", frame1}}, 2_000

    :ok = MeshxNoise.Session.handshake_recv(remote_session, decode_handshake_frame(frame1))
    {:ok, msg2} = MeshxNoise.Session.handshake_send(remote_session)
    send_handshake_from_remote(remote, msg2)

    assert_receive {:meshx_transport, :memory, {:frame, "local", frame3}}, 2_000
    :ok = MeshxNoise.Session.handshake_recv(remote_session, decode_handshake_frame(frame3))
    assert_receive {:meshx_runtime, :noise_established, :memory, "remote"}, 2_000
    :ok
  end

  defp send_handshake_from_remote(remote, message) do
    packet = Packet.new(:control, msg_id(), SessionManager.handshake_payload(message))
    {:ok, frame} = Codec.encode_packet(packet)
    assert :ok = Memory.send_frame(remote, "local", frame)
  end

  defp send_ack_from_peer(peer_id, acked_msg_id) do
    packet = Ack.packet(acked_msg_id)
    {:ok, frame} = Codec.encode_packet(packet)
    assert :ok = MeshxTransport.Memory.Hub.deliver(peer_id, "local", frame)
  end

  defp assert_ack_frame(frame, acked_msg_id) do
    assert {:ok, packet, <<>>} = Codec.decode_packet(frame)
    assert {:ok, ^acked_msg_id} = Ack.decode(packet)
  end

  defp decode_handshake_frame(frame) do
    assert {:ok, packet, <<>>} = Codec.decode_packet(frame)
    assert packet.type == :control
    assert {:ok, message} = SessionManager.decode_handshake_payload(packet.payload)
    message
  end

  defp collect_transport_frames(acc \\ []) do
    receive do
      {:meshx_transport, :memory, {:frame, "local", frame}} ->
        collect_transport_frames([frame | acc])
    after
      25 -> Enum.reverse(acc)
    end
  end

  defp assert_eventually(fun, attempts \\ 20)

  defp assert_eventually(fun, attempts) when attempts > 0 do
    if fun.() do
      assert true
    else
      Process.sleep(10)
      assert_eventually(fun, attempts - 1)
    end
  end

  defp assert_eventually(fun, 0), do: assert(fun.())

  defp restart_runtime do
    Application.stop(:meshx_runtime)
    {:ok, _apps} = Application.ensure_all_started(:meshx_runtime)
    :ok
  end

  defp flush_transport_events do
    receive do
      {:meshx_transport, _transport, _event} -> flush_transport_events()
    after
      0 -> :ok
    end
  end

  defp attach_telemetry(events) do
    id = {__MODULE__, self(), System.unique_integer([:positive])}

    :ok =
      :telemetry.attach_many(
        id,
        events,
        fn event, measurements, metadata, test_pid ->
          send(test_pid, {:telemetry, event, measurements, metadata})
        end,
        self()
      )

    on_exit(fn -> :telemetry.detach(id) end)
  end
end
