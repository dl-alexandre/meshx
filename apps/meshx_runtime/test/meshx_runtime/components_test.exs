defmodule MeshxRuntime.ComponentsTest do
  use ExUnit.Case

  @moduletag capture_log: true

  alias MeshxProtocol.Packet
  alias MeshxRuntime.{FragmentBuffer, Outbox, PeerRegistry, Router, SessionManager, Telemetry}
  alias MeshxStore.{Dedupe, Identity, RelayCache, Trust}
  alias MeshxStore.Outbox, as: StoreOutbox
  alias MeshxTransport.{Capabilities, Peer}

  setup do
    restart_runtime()
    Router.reset()
    Outbox.reset()
    SessionManager.reset()
    FragmentBuffer.reset()
    PeerRegistry.reset()
    Identity.clear()
    Trust.clear()
    Dedupe.clear()
    RelayCache.clear()
    StoreOutbox.clear()
    :ok
  end

  test "peer registry tracks peers, capabilities, and removals" do
    peer =
      Peer.new("peer-a", :tcp,
        metadata: Capabilities.to_metadata(Capabilities.new(mtu: 256, secure_required: true))
      )

    assert :ok = PeerRegistry.up(peer)
    assert PeerRegistry.get("peer-a") == peer
    assert [%{id: "peer-a"}] = PeerRegistry.list()
    assert %{mtu: 256, secure_required?: true} = PeerRegistry.capabilities("peer-a")

    assert :ok = PeerRegistry.down("peer-a")
    assert PeerRegistry.get("peer-a") == nil
    assert PeerRegistry.capabilities("peer-a") == nil
  end

  test "telemetry helper emits under the runtime prefix" do
    attach_telemetry([[:meshx_runtime, :custom, :event]])

    assert :ok = Telemetry.execute([:custom, :event], %{count: 1}, source: :test)

    assert_receive {:telemetry, [:meshx_runtime, :custom, :event], %{count: 1}, %{source: :test}}
  end

  test "fragment buffer reports malformed fragments and reset clears buffered state" do
    malformed = Packet.new(:fragment, 1, <<1, 2, 3>>)

    assert {:error, :malformed_fragment} = FragmentBuffer.add(malformed)

    fragment = Packet.new(:fragment, 2, <<123::32-little, 0::8, 2::8, "chunk">>)
    assert {:partial, 1, 2} = FragmentBuffer.add(fragment)
    assert :ok = FragmentBuffer.reset()
    assert {:partial, 1, 2} = FragmentBuffer.add(fragment)
  end

  test "session manager exposes missing and in-progress session states" do
    assert :error = SessionManager.decode_handshake_payload("not-a-handshake")

    assert {:ok, "hello"} =
             SessionManager.decode_handshake_payload(SessionManager.handshake_payload("hello"))

    assert {:error, :session_not_found} = SessionManager.encrypt("missing", "payload")
    assert {:error, :session_not_found} = SessionManager.decrypt("missing", "payload")

    assert {:ok, first_message} = SessionManager.ensure_initiator("peer-a")
    assert is_binary(first_message)
    assert {:error, :handshake_in_progress} = SessionManager.ensure_initiator("peer-a")
    refute SessionManager.established?("peer-a")
    assert {:error, :session_not_established} = SessionManager.encrypt("peer-a", "payload")

    assert :ok = SessionManager.reset()
    assert {:error, :session_not_found} = SessionManager.encrypt("peer-a", "payload")
  end

  test "session manager authorizes established peers and exposes remote keys" do
    {:ok, first_message} = SessionManager.ensure_initiator("peer-a")
    {:ok, remote_session} = MeshxNoise.Session.start_link(role: :responder)

    :ok = MeshxNoise.Session.handshake_recv(remote_session, first_message)
    {:ok, second_message} = MeshxNoise.Session.handshake_send(remote_session)

    assert {:ok, third_message, true} = SessionManager.handle_handshake("peer-a", second_message)
    :ok = MeshxNoise.Session.handshake_recv(remote_session, third_message)

    remote_key = SessionManager.remote_key("peer-a")
    assert is_binary(remote_key)
    assert Trust.trusted?("peer-a", remote_key)
    assert {:ok, :established} = SessionManager.ensure_initiator("peer-a")
  end

  test "session manager emits Noise telemetry" do
    attach_telemetry([
      [:meshx_runtime, :noise, :session, :started],
      [:meshx_runtime, :noise, :handshake, :started],
      [:meshx_runtime, :noise, :handshake, :established]
    ])

    {:ok, first_message} = SessionManager.ensure_initiator("peer-a")
    {:ok, remote_session} = MeshxNoise.Session.start_link(role: :responder)

    assert_receive {:telemetry, [:meshx_runtime, :noise, :session, :started], %{count: 1},
                    %{role: :initiator}}

    assert_receive {:telemetry, [:meshx_runtime, :noise, :handshake, :started], %{count: 1},
                    %{peer_id: "peer-a", role: :initiator}}

    :ok = MeshxNoise.Session.handshake_recv(remote_session, first_message)
    {:ok, second_message} = MeshxNoise.Session.handshake_send(remote_session)
    assert {:ok, third_message, true} = SessionManager.handle_handshake("peer-a", second_message)
    :ok = MeshxNoise.Session.handshake_recv(remote_session, third_message)

    assert_receive {:telemetry, [:meshx_runtime, :noise, :handshake, :established], %{count: 1},
                    %{peer_id: "peer-a", role: :initiator}}
  end

  test "session manager rejects key changes under pinned trust" do
    Application.put_env(:meshx_store, :trust_policy, :pinned)

    try do
      {:ok, first_message} = SessionManager.ensure_initiator("peer-a")
      {:ok, remote_session} = MeshxNoise.Session.start_link(role: :responder)

      :ok = MeshxNoise.Session.handshake_recv(remote_session, first_message)
      {:ok, second_message} = MeshxNoise.Session.handshake_send(remote_session)

      assert {:error, :untrusted_peer} = SessionManager.handle_handshake("peer-a", second_message)
    after
      Application.put_env(:meshx_store, :trust_policy, :tofu)
    end
  end

  test "session manager rejects malformed responder handshakes without crashing" do
    assert {:error, :decryption_failed} = SessionManager.handle_handshake("peer-a", "malformed")
    refute SessionManager.established?("peer-a")
  end

  test "runtime outbox returns encode errors and fails malformed stored rows" do
    attach_telemetry([
      [:meshx_runtime, :outbox, :retry, :start],
      [:meshx_runtime, :outbox, :replay, :error]
    ])

    bad_packet = %Packet{type: :bad_type, msg_id: 99, payload: <<>>}
    assert {:error, "unknown packet type: :bad_type"} = Outbox.enqueue("peer-a", bad_packet)

    assert {:ok, row} =
             StoreOutbox.enqueue(%{
               msg_id: 100,
               payload: <<1, 2>>,
               destinations: ["peer-a"],
               max_attempts: 1
             })

    assert :ok = Outbox.replay("peer-a")

    assert_eventually(fn ->
      assert %{status: :failed, attempts: 1} = StoreOutbox.get(row.id)
    end)

    assert_receive {:telemetry, [:meshx_runtime, :outbox, :replay, :error], %{count: 1},
                    %{peer_id: "peer-a", msg_id: 100}}

    assert :ok = Outbox.retry_now()
    assert_receive {:telemetry, [:meshx_runtime, :outbox, :retry, :start], %{count: 1}, _metadata}
  end

  defp assert_eventually(fun, attempts \\ 20)

  defp assert_eventually(fun, attempts) when attempts > 0 do
    try do
      fun.()
    rescue
      ExUnit.AssertionError ->
        Process.sleep(10)
        assert_eventually(fun, attempts - 1)
    end
  end

  defp assert_eventually(fun, 0), do: fun.()

  defp restart_runtime do
    Application.stop(:meshx_runtime)
    {:ok, _apps} = Application.ensure_all_started(:meshx_runtime)
    :ok
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
