defmodule MeshxTransportBLETest do
  use ExUnit.Case

  test "starts with no-op bridge" do
    {:ok, transport} = MeshxTransportBLE.start_link([])

    assert MeshxTransportBLE.peers(transport) == []
    assert {:error, :not_configured} = MeshxTransportBLE.send_frame(transport, "peer", "frame")
    assert {:error, :not_configured} = MeshxTransportBLE.broadcast_frame(transport, "frame")
  end

  test "normalizes bridge peer and frame events" do
    {:ok, transport} = MeshxTransportBLE.start_link([])

    send(transport, {:ble_peer_up, "peer-a", %{rssi: -40}})

    assert_receive {:meshx_transport, :ble, {:peer_up, %{id: "peer-a", metadata: %{rssi: -40}}}},
                   1_000

    assert [%{id: "peer-a"}] = MeshxTransportBLE.peers(transport)

    send(transport, {:ble_frame, "peer-a", "abc"})
    assert_receive {:meshx_transport, :ble, {:frame, "peer-a", "abc"}}, 1_000

    send(transport, {:ble_peer_down, "peer-a"})
    assert_receive {:meshx_transport, :ble, {:peer_down, "peer-a"}}, 1_000
    assert MeshxTransportBLE.peers(transport) == []
  end

  test "delegates sends to configured bridge modules" do
    {:ok, transport} =
      MeshxTransportBLE.start_link(bridge: __MODULE__.Bridge, bridge_opts: [owner: self()])

    assert :ok = MeshxTransportBLE.send_frame(transport, "peer-a", "frame", mtu: 20)
    assert_receive {:bridge_send, "peer-a", "frame", [mtu: 20]}

    assert :ok = MeshxTransportBLE.broadcast_frame(transport, "broadcast")
    assert_receive {:bridge_broadcast, "broadcast", []}
  end

  test "port bridge sends commands and normalizes native events" do
    {:ok, bridge} =
      MeshxTransportBLE.PortBridge.start_link(
        command: "/bin/sh",
        args: ["-c", "while IFS= read -r _line; do :; done"],
        event_target: self()
      )

    assert :ok = MeshxTransportBLE.PortBridge.send_frame(bridge, "peer-a", "frame", mtu: 20)
    assert :ok = MeshxTransportBLE.PortBridge.send_frame(bridge, "peer-a", "frame")
    assert :ok = MeshxTransportBLE.PortBridge.broadcast_frame(bridge, "broadcast")

    port = :sys.get_state(bridge).port

    send(bridge, port_event(port, {:peer_up, "peer-a", %{rssi: -50}}))
    assert_receive {:ble_peer_up, "peer-a", %{rssi: -50}}

    send(bridge, port_event(port, {:frame, "peer-a", "abc"}))
    assert_receive {:ble_frame, "peer-a", "abc"}

    send(bridge, port_event(port, {:peer_down, "peer-a"}))
    assert_receive {:ble_peer_down, "peer-a"}

    send(bridge, {port, {:data, {:eol, "not-base64"}}})
    send(bridge, port_event(port, {:unknown, "event"}))
    send(bridge, {:ignored, :message})

    send(bridge, {port, {:exit_status, 17}})
    assert_receive {:ble_bridge_down, 17}, 1_000
  end

  test "port bridge can wait for native command acknowledgements" do
    {:ok, bridge} =
      MeshxTransportBLE.PortBridge.start_link(
        command: "/bin/sh",
        args: ["-c", "while IFS= read -r _line; do :; done"],
        event_target: self(),
        command_ack?: true,
        command_timeout_ms: 500
      )

    port = :sys.get_state(bridge).port

    send_task =
      Task.async(fn ->
        MeshxTransportBLE.PortBridge.send_frame(bridge, "peer-a", "frame", mtu: 20)
      end)

    command_id = assert_pending_command(bridge)
    send(bridge, port_event(port, {:command_result, command_id, :ok}))
    assert :ok = Task.await(send_task)

    error_task =
      Task.async(fn ->
        MeshxTransportBLE.PortBridge.broadcast_frame(bridge, "broadcast")
      end)

    command_id = assert_pending_command(bridge)
    send(bridge, port_event(port, {:command_error, command_id, "native failed"}))
    assert {:error, "native failed"} = Task.await(error_task)
  end

  test "port bridge command acknowledgements time out explicitly" do
    {:ok, bridge} =
      MeshxTransportBLE.PortBridge.start_link(
        command: "/bin/sh",
        args: ["-c", "while IFS= read -r _line; do :; done"],
        event_target: self(),
        command_ack?: true,
        command_timeout_ms: 20
      )

    assert {:error, :command_timeout} =
             MeshxTransportBLE.PortBridge.send_frame(bridge, "peer-a", "frame")
  end

  test "bluez bridge builds platform command arguments" do
    args =
      MeshxTransportBLE.BluezBridge.command_args(
        adapter: "hci1",
        local_name: "meshx-test",
        mtu: 64,
        scan?: false
      )

    assert ["--adapter", "hci1"] = Enum.take(args, 2)
    assert "--no-scan" in args
    assert option_value(args, "--local-name") == "meshx-test"
    assert option_value(args, "--mtu") == "64"
    assert option_value(args, "--service-uuid")
    assert option_value(args, "--rx-uuid")
    assert option_value(args, "--tx-uuid")
  end

  test "bluez bridge delegates through the port bridge" do
    {:ok, bridge} =
      MeshxTransportBLE.BluezBridge.start_link(
        command: "/bin/sh",
        args: ["-c", "while IFS= read -r _line; do :; done"],
        event_target: self(),
        command_timeout_ms: 500
      )

    port = :sys.get_state(bridge).port

    send_task =
      Task.async(fn ->
        MeshxTransportBLE.BluezBridge.send_frame(bridge, "peer-a", "frame", mtu: 20)
      end)

    command_id = assert_pending_command(bridge)
    send(bridge, port_event(port, {:command_result, command_id, :ok}))
    assert :ok = Task.await(send_task)

    default_opts_task =
      Task.async(fn ->
        MeshxTransportBLE.BluezBridge.send_frame(bridge, "peer-a", "frame")
      end)

    command_id = assert_pending_command(bridge)
    send(bridge, port_event(port, {:command_result, command_id, :ok}))
    assert :ok = Task.await(default_opts_task)

    broadcast_task =
      Task.async(fn ->
        MeshxTransportBLE.BluezBridge.broadcast_frame(bridge, "broadcast")
      end)

    command_id = assert_pending_command(bridge)
    send(bridge, port_event(port, {:command_result, command_id, :ok}))
    assert :ok = Task.await(broadcast_task)
  end

  test "bluez bridge exposes a backend health check" do
    assert {:ok, "ok"} =
             MeshxTransportBLE.BluezBridge.health_check(
               command: "/bin/sh",
               args: ["-c", "printf 'ok\\n'"],
               timeout: 1_000
             )

    assert {:error, {:exit_status, 42, "bad"}} =
             MeshxTransportBLE.BluezBridge.health_check(
               command: "/bin/sh",
               args: ["-c", "printf 'bad\\n'; exit 42"],
               timeout: 1_000
             )

    assert {:error, {:exec, _reason}} =
             MeshxTransportBLE.BluezBridge.health_check(
               command: "/definitely/not/a/meshx/command",
               args: [],
               timeout: 1_000
             )
  end

  test "bundled bluez bridge executable passes its protocol self-test" do
    if python = System.find_executable("python3") do
      script = Path.expand("../priv/bin/meshx_bluez_bridge", __DIR__)

      assert {_output, 0} = System.cmd(python, [script, "--self-test"])
    else
      assert true
    end
  end

  defmodule Bridge do
    @behaviour MeshxTransportBLE.Bridge

    use GenServer

    @impl MeshxTransportBLE.Bridge
    def start_link(opts) do
      GenServer.start_link(__MODULE__, opts)
    end

    @impl MeshxTransportBLE.Bridge
    def send_frame(bridge, peer_id, frame, opts) do
      GenServer.call(bridge, {:send_frame, peer_id, frame, opts})
    end

    @impl MeshxTransportBLE.Bridge
    def broadcast_frame(bridge, frame, opts) do
      GenServer.call(bridge, {:broadcast_frame, frame, opts})
    end

    @impl true
    def init(opts) do
      {:ok, %{owner: Keyword.fetch!(opts, :owner)}}
    end

    @impl true
    def handle_call({:send_frame, peer_id, frame, opts}, _from, state) do
      send(state.owner, {:bridge_send, peer_id, frame, opts})
      {:reply, :ok, state}
    end

    def handle_call({:broadcast_frame, frame, opts}, _from, state) do
      send(state.owner, {:bridge_broadcast, frame, opts})
      {:reply, :ok, state}
    end
  end

  defp port_event(port, event) do
    {port, {:data, {:eol, MeshxTransportBLE.PortBridge.encode_term(event)}}}
  end

  defp option_value(args, option) do
    args
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.find_value(fn
      [^option, value] -> value
      _other -> nil
    end)
  end

  defp assert_pending_command(bridge, attempts \\ 20)

  defp assert_pending_command(bridge, attempts) when attempts > 0 do
    case :sys.get_state(bridge).pending |> Map.keys() do
      [command_id] ->
        command_id

      _other ->
        Process.sleep(10)
        assert_pending_command(bridge, attempts - 1)
    end
  end

  defp assert_pending_command(bridge, 0) do
    assert [command_id] = :sys.get_state(bridge).pending |> Map.keys()
    command_id
  end
end
