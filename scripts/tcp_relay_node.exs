defmodule MeshxScripts.TCPRelayNode do
  @moduledoc false

  alias MeshxProtocol.Packet
  alias MeshxRuntime.Router
  alias MeshxTransport.TCP

  def main do
    role = System.fetch_env!("MESHX_ROLE")
    id = System.fetch_env!("MESHX_NODE_ID")
    timeout_ms = "MESHX_TIMEOUT_MS" |> System.get_env("15000") |> String.to_integer()

    start_runtime!()
    Router.subscribe(self())

    {:ok, tcp} = TCP.start_link(id: id, event_target: Router, listen_port: 0)
    :ok = Router.attach_transport(:tcp, TCP, tcp)

    if ready_file = System.get_env("MESHX_READY_FILE") do
      File.write!(ready_file, Integer.to_string(TCP.listen_port(tcp)))
    end

    case role do
      "receiver" -> run_receiver(timeout_ms)
      "relay" -> run_relay(tcp, timeout_ms)
      "sender" -> run_sender(tcp, timeout_ms)
    end
  end

  defp run_receiver(timeout_ms) do
    payload_file = System.fetch_env!("MESHX_PAYLOAD_FILE")

    receive do
      {:meshx_runtime, :packet, :tcp, peer_id, packet} ->
        File.write!(
          payload_file,
          :erlang.term_to_binary({peer_id, packet.msg_id, packet.payload})
        )

        System.halt(0)
    after
      timeout_ms ->
        IO.puts(:stderr, "receiver timed out waiting for packet")
        System.halt(2)
    end
  end

  defp run_relay(tcp, timeout_ms) do
    downstream_id = System.fetch_env!("MESHX_DOWNSTREAM_ID")
    downstream_port = "MESHX_DOWNSTREAM_PORT" |> System.fetch_env!() |> String.to_integer()
    relayed_file = System.fetch_env!("MESHX_RELAYED_FILE")

    :ok = TCP.connect(tcp, ~c"127.0.0.1", downstream_port)
    wait_for_peer!(downstream_id, timeout_ms)

    receive do
      {:meshx_runtime, :packet, :tcp, peer_id, packet} ->
        File.write!(
          relayed_file,
          :erlang.term_to_binary({peer_id, packet.msg_id, packet.payload, packet.ttl})
        )

        # Allow async relay broadcast to complete before halting.
        Process.sleep(500)
        System.halt(0)
    after
      timeout_ms ->
        IO.puts(:stderr, "relay timed out waiting for packet")
        System.halt(2)
    end
  end

  defp run_sender(tcp, timeout_ms) do
    upstream_id = System.fetch_env!("MESHX_UPSTREAM_ID")
    upstream_port = "MESHX_UPSTREAM_PORT" |> System.fetch_env!() |> String.to_integer()
    payload = System.get_env("MESHX_PAYLOAD", "hello")
    ttl = "MESHX_TTL" |> System.get_env("8") |> String.to_integer()

    :ok = TCP.connect(tcp, ~c"127.0.0.1", upstream_port)
    wait_for_peer!(upstream_id, timeout_ms)

    msg_id = [:positive] |> System.unique_integer() |> rem(4_000_000_000)
    packet = %{Packet.new(:data, msg_id, payload) | ttl: ttl}
    :ok = Router.send_packet(upstream_id, packet)

    # Give the frame time to reach the wire before exit.
    Process.sleep(300)
    System.halt(0)
  end

  defp wait_for_peer!(peer_id, timeout_ms) do
    receive do
      {:meshx_runtime, :peer_up, :tcp, %{id: ^peer_id}} -> :ok
    after
      timeout_ms ->
        IO.puts(:stderr, "timed out waiting for peer #{peer_id}")
        System.halt(2)
    end
  end

  defp start_runtime! do
    configure_store!()
    {:ok, _apps} = Application.ensure_all_started(:meshx_store)
    {:ok, _apps} = Application.ensure_all_started(:meshx_runtime)
    :ok = MeshxRuntime.ensure_dependency_workers_started()
  end

  defp configure_store! do
    if data_dir = System.get_env("MESHX_STORE_DATA_DIR") do
      Application.put_env(:meshx_store, :data_dir, data_dir)
    end
  end
end

MeshxScripts.TCPRelayNode.main()
