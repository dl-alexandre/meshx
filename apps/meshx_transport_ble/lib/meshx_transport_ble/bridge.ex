defmodule MeshxTransportBLE.Bridge do
  @moduledoc """
  Behaviour for native/mobile BLE bridge implementations.

  Bridge implementations own platform-specific BLE details: scanning,
  advertising, GATT characteristics, MTU negotiation, background constraints,
  and mobile OS callbacks. They communicate with `MeshxTransportBLE` through
  a small message contract documented in `MeshxTransportBLE`.

  `MeshxTransportBLE.PortBridge` provides a production boundary for launching
  those native adapters as supervised external processes.
  """

  @callback start_link(keyword()) :: GenServer.on_start()
  @callback send_frame(pid(), term(), binary(), keyword()) :: :ok | {:error, term()}
  @callback broadcast_frame(pid(), binary(), keyword()) :: :ok | {:error, term()}
end
