defmodule Mob.Node.BleTransport do
  @moduledoc """
  Starts the production `mob_ble` path and attaches it to `Mob.Runtime.Router`.

  Chat send (`Router.broadcast_packet/2`) and mesh receive (`{:mob_routing, :ble, …}`)
  both require this wiring. Without `attach_transport/3`, broadcasts are no-ops
  and inbound frames never reach channel subscribers.
  """

  require Logger

  alias Mob.Node.BLE.Observability

  @type start_result :: {:ok, pid()} | {:error, term()} | :skipped

  @doc """
  Mirrors `Mob.Node.App.maybe_start_mob_ble_transport/0` for tests and production.

  Options:
    * `:local_name` — BLE advertised name (default `"mob-mobile"`)
    * `:event_target` — override router event target (default `Mob.Runtime.Router`)
    * `:force?` — when true, ignore `MOB_BLE_TRANSPORT=0` (tests only)
  """
  @spec start(keyword()) :: start_result()
  def start(opts \\ []) do
    if skip?(opts) do
      Logger.info("mob_node: mob_ble transport skipped (MOB_BLE_TRANSPORT=0)")
      rt_probe(:transport, :mob_ble_transport_skipped, %{reason: "MOB_BLE_TRANSPORT=0"})
      :skipped
    else
      do_start(opts)
    end
  end

  @doc "Returns true when `:ble` is registered on the runtime router."
  @spec attached?() :: boolean()
  def attached? do
    case router_transports() do
      %{ble: %{adapter: Mob.Routing.BLE, pid: pid}} when is_pid(pid) -> true
      _ -> false
    end
  rescue
    _ -> false
  end

  defp skip?(opts) do
    Keyword.get(opts, :force?, false) != true and System.get_env("MOB_BLE_TRANSPORT") == "0"
  end

  defp do_start(opts) do
    local_name =
      Keyword.get(opts, :local_name, System.get_env("MOB_BLE_LOCAL_NAME") || "mob-mobile")

    event_target =
      Keyword.get_lazy(opts, :event_target, fn ->
        if System.get_env("MESHX_BLE_SELFTEST") in [nil, ""] do
          Mob.Runtime.Router
        else
          Mob.Node.BleSelfTest
        end
      end)

    bridge_opts = [
      local_name: local_name,
      boot_native?: false
    ]

    transport_opts = [
      bridge: Mob.Ble.bridge_module(),
      bridge_opts: bridge_opts,
      event_target: event_target
    ]

    rt_probe(:transport, :mob_ble_transport_start_requested, %{local_name: local_name})

    case Mob.Routing.BLE.start_link(transport_opts) do
      {:ok, pid} ->
        :ok = Mob.Runtime.Router.attach_transport(:ble, Mob.Routing.BLE, pid)
        Application.put_env(:mob_node, :ble_transport_pid, pid)

        Logger.info(
          "mob_node: mob_ble transport up (bridge=#{inspect(Mob.Ble.bridge_module())}, router attached)"
        )

        rt_probe(:transport, :mob_ble_transport_started, %{
          bridge: inspect(Mob.Ble.bridge_module()),
          local_name: local_name,
          router_attached: true
        })

        {:ok, pid}

      other ->
        Logger.warning("mob_node: mob_ble transport not started: #{inspect(other)}")
        rt_probe(:transport, :mob_ble_transport_start_failed, %{reason: inspect(other)})
        {:error, other}
    end
  end

  defp router_transports do
    Mob.Runtime.Router
    |> :sys.get_state()
    |> Map.fetch!(:transports)
  end

  defp rt_probe(phase, event, metadata) do
    Observability.probe(phase, event, metadata)
  end
end
