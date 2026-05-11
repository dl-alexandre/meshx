defmodule MeshxScripts.BLEReceiver do
  @moduledoc """
  Two-node BLE smoke test — receiver side.

  Run on a Linux host with BlueZ and the `dbus-next` Python package installed.
  The sender (`scripts/ble_sender.exs`) targets this node by its BLE adapter
  MAC, not by `MESHX_NODE_ID`. Find it with:

      hciconfig hci0 | awk '/BD Address/ {print toupper($3)}'

  Pass that uppercased MAC to the sender as `MESHX_RECEIVER_ID`.

  On receipt of the first decrypted `:data` packet, writes
  `{peer_id, msg_id, payload}` (as `:erlang.term_to_binary/1`) to
  `MESHX_PAYLOAD_FILE` and exits 0. `peer_id` will be the sender's MAC.

  ## Required env

    * `MESHX_READY_FILE`   — written once the BLE transport is attached
    * `MESHX_PAYLOAD_FILE` — written once a packet arrives

  ## Optional env

    * `MESHX_NODE_ID`   — local node label (default `ble-receiver`)
    * `MESHX_TIMEOUT_MS` — wait budget for the first packet (default 60000)
    * `MESHX_BLE_ADAPTER`, `MESHX_BLE_SERVICE_UUID`, `MESHX_BLE_LOCAL_NAME`,
      `MESHX_BLE_MTU` — forwarded to the BluezBridge. The service UUID must
      match on both sides or discovery will not fire.
  """

  alias MeshxRuntime.Router
  alias MeshxTransportBLE.BluezBridge

  def main do
    id = System.get_env("MESHX_NODE_ID", "ble-receiver")
    ready_file = System.fetch_env!("MESHX_READY_FILE")
    payload_file = System.fetch_env!("MESHX_PAYLOAD_FILE")
    timeout_ms = "MESHX_TIMEOUT_MS" |> System.get_env("60000") |> String.to_integer()

    start_runtime!()
    Router.subscribe(self())

    {:ok, ble} =
      MeshxTransportBLE.start_link(
        id: id,
        event_target: Router,
        bridge: BluezBridge,
        bridge_opts: bridge_opts(id)
      )

    :ok = Router.attach_transport(:ble, MeshxTransportBLE, ble)

    File.write!(ready_file, id)

    receive do
      {:meshx_runtime, :packet, :ble, peer_id, packet} ->
        File.write!(
          payload_file,
          :erlang.term_to_binary({peer_id, packet.msg_id, packet.payload})
        )

        System.halt(0)
    after
      timeout_ms ->
        IO.puts(:stderr, "timed out waiting for BLE packet")
        System.halt(2)
    end
  end

  defp bridge_opts(id) do
    []
    |> put_env("MESHX_BLE_ADAPTER", :adapter)
    |> put_env("MESHX_BLE_SERVICE_UUID", :service_uuid)
    |> put_env("MESHX_BLE_LOCAL_NAME", :local_name, id)
    |> put_env("MESHX_BLE_MTU", :mtu, nil, &String.to_integer/1)
  end

  defp put_env(opts, env_key, opt_key, default \\ nil, cast \\ & &1) do
    case System.get_env(env_key, default) do
      nil -> opts
      value -> Keyword.put(opts, opt_key, cast.(value))
    end
  end

  defp start_runtime! do
    if data_dir = System.get_env("MESHX_STORE_DATA_DIR") do
      Application.put_env(:meshx_store, :data_dir, data_dir)
    end

    {:ok, _apps} = Application.ensure_all_started(:meshx_runtime)
    {:ok, _} = Application.ensure_all_started(:meshx_transport_ble)
  end
end

MeshxScripts.BLEReceiver.main()
