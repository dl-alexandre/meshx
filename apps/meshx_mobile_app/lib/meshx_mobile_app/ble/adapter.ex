defmodule MeshxMobileApp.BLE.Adapter do
  @moduledoc """
  Behaviour every platform BLE bridge implements.

  Replaces the earlier `MeshxMobileApp.NativeBridge` behaviour. Both
  iOS (`MeshxMobileApp.NativeBridge.IOS`) and the future Android bridge
  conform to this single surface. Adapters do transport only —
  lifecycle policy, mesh identity, and event normalization live in
  the runtime, not in Swift or Kotlin.

  ## Event delivery

  Adapters must deliver events to the configured owner as

      {MeshxMobileApp.BLE.Adapter, :event, %MeshxMobileApp.BLE.Events.X{}}

  built via `event_message/1`. Anything else violates the contract.
  """

  alias MeshxMobileApp.BLE.{BridgeProtocol, Event}

  @type owner :: pid()
  @type local_name :: String.t()
  @type device_id :: binary()
  @type peer_id :: binary()
  @type payload :: binary()
  @type reason :: term()

  @callback start_scan(owner()) :: :ok | {:error, reason()}
  @callback start_advertising(owner(), local_name()) :: :ok | {:error, reason()}
  @callback stop(owner()) :: :ok | {:error, reason()}
  @callback send_to_peer(owner(), peer_id(), payload()) :: :ok | {:error, reason()}

  @doc """
  Builds the canonical bridge-event message envelope.

  Accepts either a canonical event struct or a raw bridge payload —
  raw payloads are normalized through `BridgeProtocol.decode/1` and
  any decode error becomes a `%MeshxMobileApp.BLE.Events.Error{}`.
  """
  @spec event_message(Event.t() | term()) ::
          {__MODULE__, :event, Event.t()}
  def event_message(event) do
    cond do
      Event.event?(event) ->
        {__MODULE__, :event, event}

      true ->
        case BridgeProtocol.decode(event) do
          {:ok, normalized} ->
            {__MODULE__, :event, normalized}

          {:error, reason} ->
            {__MODULE__, :event,
             %MeshxMobileApp.BLE.Events.Error{
               kind: :unknown,
               detail: "bridge protocol decode failed: " <> inspect(reason)
             }}
        end
    end
  end

  @spec configured() :: module()
  def configured do
    Application.get_env(:meshx_mobile_app, :ble_adapter, MeshxMobileApp.NativeBridge.Noop)
  end
end
