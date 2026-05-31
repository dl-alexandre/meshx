defmodule Mob.Routing.BLE.NoopBridge do
  @moduledoc """
  Default BLE bridge used when no native bridge is configured.

  It allows the adapter to start in desktop/test environments while making send
  attempts fail explicitly with `{:error, :not_configured}`.
  """

  @behaviour Mob.Routing.BLE.Bridge

  use GenServer

  @impl Mob.Routing.BLE.Bridge
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl Mob.Routing.BLE.Bridge
  def send_frame(_bridge, _peer_id, _frame, _opts \\ []) do
    {:error, :not_configured}
  end

  @impl Mob.Routing.BLE.Bridge
  def broadcast_frame(_bridge, _frame, _opts \\ []) do
    {:error, :not_configured}
  end

  @impl true
  def init(opts) do
    {:ok, Map.new(opts)}
  end
end
