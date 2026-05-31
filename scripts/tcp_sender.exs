defmodule MobScripts.TCPSender do
  @moduledoc false

  alias Mob.Protocol.Packet
  alias Mob.Runtime.Router
  alias Mob.Routing.TCP

  def main do
    id = System.get_env("MESHX_NODE_ID", "sender")
    receiver_id = System.fetch_env!("MESHX_RECEIVER_ID")
    receiver_host = System.get_env("MESHX_RECEIVER_HOST", "127.0.0.1")
    receiver_port = "MESHX_RECEIVER_PORT" |> System.fetch_env!() |> String.to_integer()
    payload = System.get_env("MESHX_PAYLOAD", "hello")
    timeout_ms = "MESHX_TIMEOUT_MS" |> System.get_env("10000") |> String.to_integer()

    start_runtime!()
    Router.subscribe(self())

    {:ok, tcp} = TCP.start_link(id: id, event_target: Router, listen_port: 0)
    :ok = Router.attach_transport(:tcp, TCP, tcp)
    :ok = TCP.connect(tcp, receiver_host, receiver_port)

    wait_for_peer!(receiver_id, timeout_ms)

    packet = Packet.new(:data, [:positive] |> System.unique_integer() |> rem(4_000_000_000), payload)
    :ok = Router.send_packet(receiver_id, packet)
  end

  defp wait_for_peer!(receiver_id, timeout_ms) do
    receive do
      {:mob_runtime, :peer_up, :tcp, %{id: ^receiver_id}} -> :ok
    after
      timeout_ms ->
        IO.puts(:stderr, "timed out waiting for TCP peer #{receiver_id}")
        System.halt(2)
    end
  end

  defp start_runtime! do
    configure_store!()
    {:ok, _apps} = Application.ensure_all_started(:mob_store)
    {:ok, _apps} = Application.ensure_all_started(:mob_runtime)
    :ok = Mob.Runtime.ensure_dependency_workers_started()
  end

  defp configure_store! do
    if data_dir = System.get_env("MESHX_STORE_DATA_DIR") do
      Application.put_env(:mob_store, :data_dir, data_dir)
    end
  end
end

MobScripts.TCPSender.main()
