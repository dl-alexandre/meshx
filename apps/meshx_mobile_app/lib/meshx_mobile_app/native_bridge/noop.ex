defmodule MeshxMobileApp.NativeBridge.Noop do
  @moduledoc """
  Host-test adapter used before a platform bridge is loaded.

  Emits canonical events via the v1 wire format so tests exercise the
  same normalization path that platform bridges will take in production.
  """

  @behaviour MeshxMobileApp.BLE.Adapter

  alias MeshxMobileApp.BLE.Adapter

  @impl true
  def start_scan(owner) do
    send(owner, Adapter.event_message(%{v: 1, event: "device_lost", device_id: "noop"}))
    :ok
  end

  @impl true
  def start_advertising(owner, _local_name) do
    send(owner, Adapter.event_message(%{v: 1, event: "device_lost", device_id: "noop"}))
    :ok
  end

  @impl true
  def stop(owner) do
    send(
      owner,
      Adapter.event_message(%{
        v: 1,
        event: "connection_state_changed",
        device_id: "noop",
        state: "disconnected"
      })
    )

    :ok
  end

  @impl true
  def send_to_peer(owner, _peer_id, _payload) do
    send(
      owner,
      Adapter.event_message(%{
        v: 1,
        event: "error",
        kind: "not_connected",
        detail: "noop adapter has no peer"
      })
    )

    :ok
  end
end
