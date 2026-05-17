defmodule MeshxScripts.BLESender do
  @moduledoc """
  Two-node BLE smoke test — sender side.

  Run on a Linux host with BlueZ and the `dbus-next` Python package installed,
  alongside a peer running `scripts/ble_receiver.exs`.

  ## Required env

    * `MESHX_RECEIVER_ID` — the receiver's BLE adapter MAC, **uppercased** (e.g.
      `AA:BB:CC:DD:EE:FF`). This is the `peer_id` the BlueZ bridge emits, derived
      from `org.bluez.Device1.Address`. It is **not** the receiver's
      `MESHX_NODE_ID` / `--local-name`, which is only the advertised friendly
      name. On the receiver host, get the MAC with:

          hciconfig hci0 | awk '/BD Address/ {print toupper($3)}'

  ## Optional env

    * `MESHX_NODE_ID`   — local node label (default `ble-sender`)
    * `MESHX_PAYLOAD`   — payload bytes (default `hello-ble`)
    * `MESHX_TIMEOUT_MS` — wait budget for peer + Noise (default 60000)
    * `MESHX_BLE_ADAPTER`, `MESHX_BLE_SERVICE_UUID`, `MESHX_BLE_LOCAL_NAME`,
      `MESHX_BLE_MTU`, `MESHX_BLE_COMMAND_TIMEOUT_MS` — forwarded to the
      BluezBridge. The service UUID must match on both sides or discovery
      will not fire. The command timeout defaults to 30s (BlueZ cold connect
      can take 5–30s); shorten only if you know the peer is already paired.
  """

  alias MeshxProtocol.Packet
  alias MeshxRuntime.Router
  alias MeshxTransportBLE.BluezBridge

  def main do
    id = System.get_env("MESHX_NODE_ID", "ble-sender")
    receiver_id = System.fetch_env!("MESHX_RECEIVER_ID")
    payload = System.get_env("MESHX_PAYLOAD", "hello-ble")
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

    wait_for_peer!(receiver_id, timeout_ms)
    wait_for_noise!(receiver_id, timeout_ms)

    packet = Packet.new(:data, [:positive] |> System.unique_integer() |> rem(4_000_000_000), payload)
    :ok = Router.send_packet(receiver_id, packet)
  end

  defp wait_for_peer!(receiver_id, timeout_ms) do
    receive do
      {:meshx_runtime, :peer_up, :ble, %{id: ^receiver_id}} -> :ok
    after
      timeout_ms ->
        IO.puts(:stderr, "timed out waiting for BLE peer #{receiver_id}")
        System.halt(2)
    end
  end

  defp wait_for_noise!(receiver_id, timeout_ms) do
    receive do
      {:meshx_runtime, :noise_established, :ble, ^receiver_id} -> :ok
    after
      timeout_ms ->
        IO.puts(:stderr, "timed out waiting for Noise handshake with #{receiver_id}")
        System.halt(2)
    end
  end

  defp bridge_opts(id) do
    []
    |> put_env("MESHX_BLE_ADAPTER", :adapter)
    |> put_env("MESHX_BLE_SERVICE_UUID", :service_uuid)
    |> put_env("MESHX_BLE_LOCAL_NAME", :local_name, id)
    |> put_env("MESHX_BLE_MTU", :mtu, nil, &String.to_integer/1)
    |> put_env("MESHX_BLE_COMMAND_TIMEOUT_MS", :command_timeout_ms, nil, &String.to_integer/1)
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

    {:ok, _apps} = Application.ensure_all_started(:meshx_store)
    {:ok, _apps} = Application.ensure_all_started(:meshx_runtime)
    :ok = MeshxRuntime.ensure_dependency_workers_started()
    {:ok, _} = Application.ensure_all_started(:meshx_transport_ble)
  end
end

MeshxScripts.BLESender.main()
