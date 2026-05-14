defmodule MeshxMobileApp.BleSelfTest do
  @moduledoc """
  Headless on-device BLE bring-up probe.

  Started by `MeshxMobileApp.App.on_start/0` only when the
  `MESHX_BLE_SELFTEST` env var is set (the Android launcher derives it
  from the `meshx_ble_selftest` intent extra). It exercises the real
  `meshx_ble_nif` path end to end without any UI:

    1. `:meshx_ble_nif.start_scan/1` + `:meshx_ble_nif.start_advertising/2`
       with this process as the owner pid.
    2. Receives `{MeshxMobileApp.NativeBridge, :bridge_event, json}`
       messages, runs each through `BLE.Adapter.event_message/1`, and
       logs the canonical event under the `MeshxBleSelfTest` tag.

  Two devices each running this probe should log each other's
  advertisements — that is the on-device two-node BLE mesh check.
  """

  use GenServer

  require Logger

  alias MeshxMobileApp.BLE.Adapter

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @heartbeat_ms 5_000

  @impl true
  def init(opts) do
    local_name = Keyword.get(opts, :local_name, default_local_name())

    state = %{
      local_name: local_name,
      discovered: MapSet.new(),
      event_count: 0,
      meshx_peers: MapSet.new()
    }

    {:ok, state, {:continue, :start_ble}}
  end

  @impl true
  def handle_continue(:start_ble, state) do
    nif = :meshx_ble_nif

    Logger.info("BleSelfTest: starting scan + advertising as #{state.local_name}")

    scan = safe_call(fn -> nif.start_scan(self()) end)
    adv = safe_call(fn -> nif.start_advertising(self(), state.local_name) end)

    Logger.info("BleSelfTest: start_scan=#{inspect(scan)} start_advertising=#{inspect(adv)}")
    Process.send_after(self(), :heartbeat, @heartbeat_ms)
    {:noreply, state}
  end

  @impl true
  def handle_info(:heartbeat, state) do
    # Periodic proof-of-life: distinguishes "pipeline working, just no
    # MeshX peer correlated yet" from "no BLE events reaching the BEAM".
    Logger.info(
      "BleSelfTest: HEARTBEAT events=#{state.event_count} " <>
        "devices=#{MapSet.size(state.discovered)} " <>
        "meshx_peers=#{MapSet.size(state.meshx_peers)}"
    )

    Process.send_after(self(), :heartbeat, @heartbeat_ms)
    {:noreply, state}
  end

  def handle_info({MeshxMobileApp.NativeBridge, :bridge_event, _raw} = msg, state) do
    {MeshxMobileApp.NativeBridge, :bridge_event, raw} = msg
    state = %{state | event_count: state.event_count + 1}

    state =
      case Adapter.event_message(raw) do
        {Adapter, :event, %MeshxMobileApp.BLE.Events.DeviceDiscovered{} = e} ->
          maybe_log_meshx_peer(e.device_id, e.rssi, e.advertisement, state)

        {Adapter, :event, %MeshxMobileApp.BLE.Events.AdvertisementReceived{} = e} ->
          maybe_log_meshx_peer(e.device_id, e.rssi, e.advertisement, state)

        {Adapter, :event, %MeshxMobileApp.BLE.Events.Error{} = e} ->
          Logger.warning("BleSelfTest: bridge error #{e.kind}: #{e.detail}")
          state

        {Adapter, :event, _event} ->
          state
      end

    {:noreply, state}
  end

  # A MeshX peer tablet advertises its adapter name ("meshx-<suffix>");
  # that ASCII lands in the raw advertisement bytes. Log the first sight
  # of each MeshX peer distinctly — that line is the two-device mesh
  # proof: this BEAM, over the real meshx_ble_nif path, saw the other
  # BEAM's BLE advertisement.
  defp maybe_log_meshx_peer(device_id, rssi, advertisement, state) do
    # The canonical event's `advertisement` field arrives base64-encoded
    # on the Android JSON-wire path (BleEvent.toJsonObject does .toBase64()
    # and BridgeProtocol keeps it as the wire string). Decode to raw bytes
    # before scanning for the peer's "meshx-*" manufacturer-data tag.
    bytes = advertisement_bytes(advertisement)

    state = %{state | discovered: MapSet.put(state.discovered, device_id)}

    if is_binary(bytes) and meshx_advertisement?(bytes) and
         not MapSet.member?(state.meshx_peers, device_id) do
      Logger.info(
        "BleSelfTest: MESHX PEER device_id=#{device_id} rssi=#{rssi} " <>
          "name=#{extract_name(bytes)}"
      )

      %{state | meshx_peers: MapSet.put(state.meshx_peers, device_id)}
    else
      state
    end
  end

  # `advertisement` may be raw bytes (atom-keyed map path) or a base64
  # string (Android JSON-wire path). Normalize to raw bytes.
  defp advertisement_bytes(advertisement) when is_binary(advertisement) do
    case Base.decode64(advertisement) do
      {:ok, decoded} -> decoded
      :error -> advertisement
    end
  end

  defp advertisement_bytes(_), do: <<>>

  defp meshx_advertisement?(bytes) do
    bytes
    |> :binary.bin_to_list()
    |> printable_runs()
    |> Enum.any?(&String.contains?(&1, "meshx"))
  end

  defp extract_name(bytes) do
    bytes
    |> :binary.bin_to_list()
    |> printable_runs()
    |> Enum.find("?", &String.contains?(&1, "meshx"))
  end

  # Split a byte list into runs of >=4 printable ASCII chars.
  defp printable_runs(bytes) do
    bytes
    |> Enum.chunk_by(&(&1 in 32..126))
    |> Enum.filter(fn run -> hd(run) in 32..126 and length(run) >= 4 end)
    |> Enum.map(&List.to_string/1)
  end

  def handle_info(other, state) do
    Logger.debug("BleSelfTest: unexpected #{inspect(other)}")
    {:noreply, state}
  end

  defp safe_call(fun) do
    fun.()
  rescue
    error -> {:error, error}
  end

  defp default_local_name do
    suffix = System.get_env("MOB_NODE_SUFFIX") || "dev"
    "meshx-#{suffix}"
  end
end
