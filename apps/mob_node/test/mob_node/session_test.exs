defmodule Mob.Node.SessionTest do
  use ExUnit.Case

  alias Mob.Node.BLE.Adapter
  alias Mob.Node.BLE.Capabilities
  alias Mob.Node.BLE.Events
  alias Mob.Node.BLE.LocalInbox
  alias Mob.Node.BLE.LocalInboxStore
  alias Mob.Node.BLE.MessageEnvelope
  alias Mob.Node.Session

  defmodule Bridge do
    @behaviour Adapter

    @impl true
    def start_scan(owner) do
      send(
        owner,
        Adapter.event_message(%Events.ConnectionStateChanged{
          device_id: "device-1",
          transport: :ble,
          state: :connected
        })
      )

      send(
        owner,
        Adapter.event_message(%Events.PeerAuthenticated{
          peer_id: "phone-peer",
          device_id: "device-1",
          transport: :ble,
          capabilities: Capabilities.new(roles: [:central, :peripheral])
        })
      )

      :ok
    end

    @impl true
    def start_advertising(owner, local_name) do
      # Test still emits via v1 wire format so the BridgeProtocol decode
      # path is exercised end-to-end. `local_name` is recorded by the
      # status path inside Session via "Advertising started".
      send(
        owner,
        Adapter.event_message(%{
          v: 1,
          event: "device_discovered",
          device_id: "central-" <> local_name,
          rssi: -55,
          advertisement: <<>>,
          observed_at_ms: 0
        })
      )

      :ok
    end

    @impl true
    def stop(owner) do
      send(
        owner,
        Adapter.event_message(%Events.ConnectionStateChanged{
          device_id: "device-1",
          transport: :ble,
          state: :disconnected
        })
      )

      :ok
    end

    @impl true
    def send_to_peer(owner, peer_id, payload) do
      send(
        owner,
        Adapter.event_message(%Events.MessageReceived{
          peer_id: peer_id,
          transport: :ble,
          payload: payload,
          received_at_ms: 0
        })
      )

      :ok
    end
  end

  setup do
    Application.ensure_all_started(:mob_store)
    ensure_db_started()
    LocalInboxStore.clear()
    on_exit(fn -> LocalInboxStore.clear() end)
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

  test "scan mode records authenticated peer and ping events through the canonical contract" do
    {:ok, session} = Session.start_link(bridge: Bridge)
    :ok = Session.subscribe(session)

    snapshot = Session.start(session)
    assert snapshot.mode == :scan
    assert snapshot.status == "Scanning"

    assert_receive {Session, :updated, %{peer_id: "phone-peer", status: "Secure peer connected"}}

    snapshot = Session.send_ping(session)
    assert snapshot.peer_id == "phone-peer"
    assert Enum.any?(snapshot.events, &(&1.title == "Ping sent"))

    assert_eventually(fn ->
      session
      |> Session.snapshot()
      |> Map.fetch!(:events)
      |> Enum.any?(&(&1.title == "Frame received"))
    end)
  end

  test "advertise mode delegates to bridge with mobile local name" do
    {:ok, session} = Session.start_link(bridge: Bridge)

    snapshot = Session.set_mode(session, :advertise)
    assert snapshot.mode == :advertise

    snapshot = Session.start(session)
    assert snapshot.status == "Advertising"

    assert_eventually(fn ->
      session
      |> Session.snapshot()
      |> Map.fetch!(:events)
      |> Enum.any?(&(&1.title == "Device discovered"))
    end)
  end

  test "ping without a connected peer stays local" do
    {:ok, session} = Session.start_link(bridge: Bridge)

    snapshot = Session.send_ping(session)

    assert snapshot.peer_id == nil
    assert hd(snapshot.events).title == "Send skipped"
  end

  test "snapshot exposes full messages and unresolved beacon refs in local inbox" do
    {:ok, session} = Session.start_link(bridge: Bridge)
    {:ok, envelope} = envelope()

    send(
      session,
      Adapter.event_message(%Events.ReceivedMessage{
        message_id: envelope.message_id,
        sender_peer_id: envelope.sender_peer_id,
        recipient_peer_id: envelope.recipient_peer_id,
        received_device_id: "AA:01",
        received_at: 100,
        rssi: -51,
        envelope: envelope,
        raw_transport_metadata: %{}
      })
    )

    send(
      session,
      Adapter.event_message(%Events.ReceivedMessageBeacon{
        beacon_version: 1,
        envelope_version: 1,
        payload_kind: "TX",
        message_id_hash: <<1, 2, 3, 4, 5, 6, 7, 8>>,
        sender_peer_id_hash: <<8, 7, 6, 5, 4, 3, 2, 1>>,
        received_device_id: "AA:02",
        received_at: 110,
        rssi: -60,
        raw_transport_metadata: %{}
      })
    )

    assert_eventually(fn ->
      snapshot = Session.snapshot(session)

      match?([%{envelope: ^envelope}], snapshot.local_inbox.full_messages) and
        match?(
          [%{message_id_hash: <<1, 2, 3, 4, 5, 6, 7, 8>>}],
          snapshot.local_inbox.unresolved_beacon_refs
        )
    end)
  end

  test "legacy iOS NIF bridge envelope normalizes v1 beacon maps into local inbox" do
    {:ok, session} = Session.start_link(bridge: Bridge)

    send(
      session,
      {Mob.Node.NativeBridge, :bridge_event,
       %{
         v: 1,
         event: "received_message_beacon",
         beacon_version: 1,
         envelope_version: 1,
         payload_kind: "TX",
         message_id_hash: <<1, 1, 1, 1, 1, 1, 1, 1>>,
         sender_peer_id_hash: <<2, 2, 2, 2, 2, 2, 2, 2>>,
         received_device_id: "ios-device",
         received_at: 123,
         rssi: -67,
         raw_transport_metadata: %{
           transport: "ble_ios_advertisement",
           source_event: "advertisement_received"
         }
       }}
    )

    assert_eventually(fn ->
      snapshot = Session.snapshot(session)

      match?(
        [%{source_device_ids: ["ios-device"], message_id_hash: <<1, 1, 1, 1, 1, 1, 1, 1>>}],
        snapshot.local_inbox.unresolved_beacon_refs
      )
    end)
  end

  test "local inbox persistence is disabled by default" do
    {:ok, session} = Session.start_link(bridge: Bridge)
    {:ok, envelope} = envelope()

    send(session, received_message(envelope))

    assert_eventually(fn ->
      Session.snapshot(session).local_inbox.full_messages != []
    end)

    snapshot = Session.snapshot(session)
    refute snapshot.local_inbox_persistence.enabled?
    assert snapshot.local_inbox_persistence.last_saved_at == nil
    assert {:error, :not_found} = LocalInboxStore.load(:default)
  end

  test "opt-in local inbox persistence saves received messages" do
    {:ok, session} =
      Session.start_link(
        bridge: Bridge,
        persist_local_inbox?: true,
        local_inbox_snapshot_id: :session_persist_test,
        persisted_at_fun: fn -> 10_000 end
      )

    {:ok, envelope} = envelope()
    send(session, received_message(envelope))

    assert_eventually(fn ->
      case LocalInboxStore.load_read_model(:session_persist_test) do
        {:ok, %{nearby_messages: [%{state: :full_message, envelope: ^envelope}]}} -> true
        _other -> false
      end
    end)

    snapshot = Session.snapshot(session)
    assert snapshot.local_inbox_persistence.enabled?
    assert snapshot.local_inbox_persistence.last_saved_at == 10_000
    assert snapshot.local_inbox_persistence.last_error == nil
  end

  test "opt-in restore exposes saved local inbox read model without mutating live inbox" do
    {:ok, envelope} = envelope()

    durable =
      LocalInbox.new()
      |> LocalInbox.ingest(received_message_event(envelope))
      |> LocalInbox.snapshot()

    assert {:ok, _saved} =
             LocalInboxStore.save(durable,
               snapshot_id: :session_restore_test,
               persisted_at: 10_000
             )

    {:ok, session} =
      Session.start_link(
        bridge: Bridge,
        restore_local_inbox?: true,
        local_inbox_snapshot_id: :session_restore_test
      )

    snapshot = Session.snapshot(session)

    assert snapshot.local_inbox.full_messages == []
    assert snapshot.local_inbox_persistence.restored?

    assert [%{state: :full_message, envelope: ^envelope}] =
             snapshot.restored_local_inbox.nearby_messages
  end

  defp envelope do
    MessageEnvelope.build(
      message_id: <<1::128>>,
      sender_peer_id: "meshx-alpha",
      recipient_peer_id: "meshx-beta",
      created_at: 1_700_000_000_000,
      ttl: 1,
      payload_type: "TX",
      payload: "hi",
      capability_requirements: 0
    )
  end

  defp received_message(envelope) do
    Adapter.event_message(received_message_event(envelope))
  end

  defp received_message_event(envelope) do
    %Events.ReceivedMessage{
      message_id: envelope.message_id,
      sender_peer_id: envelope.sender_peer_id,
      recipient_peer_id: envelope.recipient_peer_id,
      received_device_id: "AA:01",
      received_at: 100,
      rssi: -51,
      envelope: envelope,
      raw_transport_metadata: %{}
    }
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
end
