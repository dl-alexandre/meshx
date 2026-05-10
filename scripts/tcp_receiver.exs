defmodule MeshxScripts.TCPReceiver do
  @moduledoc false

  alias MeshxRuntime.Router
  alias MeshxTransport.TCP

  def main do
    id = System.get_env("MESHX_NODE_ID", "receiver")
    ready_file = System.fetch_env!("MESHX_READY_FILE")
    payload_file = System.fetch_env!("MESHX_PAYLOAD_FILE")
    timeout_ms = System.get_env("MESHX_TIMEOUT_MS", "10000") |> String.to_integer()

    start_runtime!()
    Router.subscribe(self())

    {:ok, tcp} = TCP.start_link(id: id, event_target: Router, listen_port: 0)
    :ok = Router.attach_transport(:tcp, TCP, tcp)

    tcp
    |> TCP.listen_port()
    |> Integer.to_string()
    |> then(&File.write!(ready_file, &1))

    receive do
      {:meshx_runtime, :packet, :tcp, peer_id, packet} ->
        File.write!(
          payload_file,
          :erlang.term_to_binary({peer_id, packet.msg_id, packet.payload})
        )

        System.halt(0)
    after
      timeout_ms ->
        IO.puts(:stderr, "timed out waiting for TCP packet")
        System.halt(2)
    end
  end

  defp start_runtime! do
    configure_store!()
    {:ok, _apps} = Application.ensure_all_started(:meshx_runtime)
  end

  defp configure_store! do
    if data_dir = System.get_env("MESHX_STORE_DATA_DIR") do
      Application.put_env(:meshx_store, :data_dir, data_dir)
    end
  end
end

MeshxScripts.TCPReceiver.main()
