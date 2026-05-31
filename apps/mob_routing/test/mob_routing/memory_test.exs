defmodule Mob.Routing.MemoryTest do
  use ExUnit.Case

  alias Mob.Routing.{Capabilities, Memory, Memory.Hub}

  setup do
    Hub.reset()
    :ok
  end

  test "announces peers when endpoints register" do
    {:ok, a} = Memory.start_link(id: "a")
    {:ok, _b} = Memory.start_link(id: "b")

    assert_receive {:mob_routing, :memory, {:peer_up, %{id: "a"}}}
    assert_receive {:mob_routing, :memory, {:peer_up, %{id: "b"}}}

    assert [%{id: "b"}] = Memory.peers(a)
  end

  test "peer descriptors include defaults and custom attributes" do
    peer = Mob.Routing.Peer.new("peer-a", :memory)

    assert peer.id == "peer-a"
    assert peer.transport == :memory
    assert peer.address == nil
    assert peer.metadata == %{}
    assert is_integer(peer.seen_at)

    custom =
      Mob.Routing.Peer.new("peer-b", :tcp,
        address: "127.0.0.1",
        metadata: %{mtu: 100},
        seen_at: 1
      )

    assert custom.address == "127.0.0.1"
    assert custom.metadata == %{mtu: 100}
    assert custom.seen_at == 1
  end

  test "sends frames between endpoints" do
    {:ok, a} = Memory.start_link(id: "a")
    {:ok, _b} = Memory.start_link(id: "b")

    flush_transport_events()

    assert :ok = Memory.send_frame(a, "b", "hello")
    assert_receive {:mob_routing, :memory, {:frame, "a", "hello"}}
  end

  test "transport API wrappers delegate to adapters" do
    {:ok, a} = Memory.start_link(id: "a")
    {:ok, _b} = Memory.start_link(id: "b")

    flush_transport_events()

    assert :ok = Mob.Routing.send_frame(Memory, a, "b", "wrapped")
    assert_receive {:mob_routing, :memory, {:frame, "a", "wrapped"}}

    assert [%{id: "b"}] = Mob.Routing.peers(Memory, a)
    assert :ok = Mob.Routing.broadcast_frame(Memory, a, "broadcast")
    assert_receive {:mob_routing, :memory, {:frame, "a", "broadcast"}}
  end

  test "broadcasts frames to all peers except sender" do
    {:ok, a} = Memory.start_link(id: "a")
    {:ok, _b} = Memory.start_link(id: "b")
    {:ok, _c} = Memory.start_link(id: "c")

    flush_transport_events()

    assert :ok = Memory.broadcast_frame(a, "hello-all")

    assert_receive {:mob_routing, :memory, {:frame, "a", "hello-all"}}
    assert_receive {:mob_routing, :memory, {:frame, "a", "hello-all"}}
    refute_receive {:mob_routing, :memory, {:frame, "a", "hello-all"}}
  end

  test "returns an error for unknown peers" do
    {:ok, a} = Memory.start_link(id: "a")
    assert {:error, :peer_not_found} = Memory.send_frame(a, "missing", "hello")
  end

  test "advertises peer capabilities" do
    {:ok, _a} = Memory.start_link(id: "a")

    {:ok, _b} =
      Memory.start_link(id: "b", capabilities: %{mtu: 80, secure_required: true, relay: false})

    assert_receive {:mob_routing, :memory, {:peer_up, %{id: "a"}}}
    assert_receive {:mob_routing, :memory, {:peer_up, %{id: "b", metadata: metadata}}}

    capabilities = Capabilities.from_metadata(metadata)
    assert capabilities.mtu == 80
    assert capabilities.secure_required?
    refute capabilities.relay?
  end

  test "advertises mtu metadata without a capabilities wrapper" do
    {:ok, _a} = Memory.start_link(id: "a")
    {:ok, _b} = Memory.start_link(id: "b", mtu: 64)

    assert_receive {:mob_routing, :memory, {:peer_up, %{id: "a"}}}
    assert_receive {:mob_routing, :memory, {:peer_up, %{id: "b", metadata: %{mtu: 64}}}}
  end

  test "merges capabilities conservatively" do
    local = Capabilities.new(mtu: 120, secure_required: false, relay: true)
    remote = Capabilities.new(mtu: 80, secure_required: true, relay: false)

    merged = Capabilities.merge(local, remote)
    assert merged.mtu == 80
    assert merged.secure_required?
    refute merged.relay?
  end

  test "capabilities merge preserves available mtu and stricter background mode" do
    local = Capabilities.new(mtu: nil, background_mode: :foreground)
    remote = Capabilities.new(mtu: 128, background_mode: :background)

    merged = Capabilities.merge(local, remote)
    assert merged.mtu == 128
    assert merged.background_mode == :background

    assert Capabilities.merge(Capabilities.new(mtu: 256), Capabilities.new(mtu: nil)).mtu == 256
  end

  test "capabilities decode nested and string-keyed metadata" do
    capabilities =
      Capabilities.new(%{
        "mtu" => 100,
        "secure_required" => true,
        "background_mode" => :background
      })

    metadata = Capabilities.to_metadata(capabilities)

    assert %{mtu: 100, secure_required?: true, background_mode: :background} =
             Capabilities.from_metadata(metadata)

    assert %{mtu: 100, secure_required?: true} =
             Capabilities.from_metadata(%{
               "capabilities" => %{"mtu" => 100, "secure_required" => true}
             })
  end

  test "capabilities decode structs and top-level metadata" do
    capabilities = Capabilities.new(protocol_version: 2, relay?: false)

    assert ^capabilities = Capabilities.from_metadata(%{capabilities: capabilities})
    assert ^capabilities = Capabilities.from_metadata(%{"capabilities" => capabilities})

    decoded =
      Capabilities.from_metadata(%{
        "protocol_version" => 3,
        "mtu" => 256,
        "secure_required?" => true,
        "relay?" => false
      })

    assert decoded.protocol_version == 3
    assert decoded.mtu == 256
    assert decoded.secure_required?
    refute decoded.relay?
  end

  test "capabilities merge keeps background mode when local is stricter" do
    merged =
      Capabilities.merge(
        Capabilities.new(background_mode: :background),
        Capabilities.new(background_mode: :foreground)
      )

    assert merged.background_mode == :background
  end

  test "hub ignores unknown down messages and missing unregisters" do
    {:ok, a} = Memory.start_link(id: "a")

    assert :ok = Hub.unregister("missing")
    send(Process.whereis(Hub), {:DOWN, make_ref(), :process, self(), :normal})

    assert_eventually(fn -> Memory.peers(a) == [] end)
  end

  test "broadcast can exclude a peer" do
    {:ok, a} = Memory.start_link(id: "a")
    {:ok, _b} = Memory.start_link(id: "b")
    {:ok, _c} = Memory.start_link(id: "c")

    flush_transport_events()

    assert :ok = Memory.broadcast_frame(a, "only-c", except: ["b"])
    assert_receive {:mob_routing, :memory, {:frame, "a", "only-c"}}
    refute_receive {:mob_routing, :memory, {:frame, "a", "only-c"}}, 25
  end

  test "hub unregister and endpoint shutdown emit peer_down" do
    {:ok, _a} = Memory.start_link(id: "a")
    {:ok, _b} = Memory.start_link(id: "b")
    flush_transport_events()

    assert :ok = Hub.unregister("b")
    assert_receive {:mob_routing, :memory, {:peer_down, "b"}}

    {:ok, c} = Memory.start_link(id: "c")
    flush_transport_events()

    GenServer.stop(c)
    assert_receive {:mob_routing, :memory, {:peer_down, "c"}}
  end

  defp flush_transport_events do
    receive do
      {:mob_routing, _transport, _event} -> flush_transport_events()
    after
      0 -> :ok
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
end
