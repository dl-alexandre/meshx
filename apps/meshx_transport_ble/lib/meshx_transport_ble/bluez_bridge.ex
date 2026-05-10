defmodule MeshxTransportBLE.BluezBridge do
  @moduledoc """
  Linux BlueZ bridge for the BLE transport.

  This bridge uses `MeshxTransportBLE.PortBridge` to supervise the bundled
  `priv/bin/meshx_bluez_bridge` executable. The executable talks to BlueZ over
  D-Bus, registers the MeshX BLE GATT service, starts LE discovery, and forwards
  normalized peer/frame events back through the standard port protocol.

  The native side requires Linux with BlueZ and the Python `dbus-next` package.
  It is intentionally optional so desktop tests and mobile builds can continue
  to provide their own bridge modules.
  """

  @behaviour MeshxTransportBLE.Bridge

  alias MeshxTransportBLE.PortBridge

  @default_service_uuid "8f4f1201-6f3d-4f9c-9e3b-7f4a4f0f1000"
  @default_rx_uuid "8f4f1202-6f3d-4f9c-9e3b-7f4a4f0f1000"
  @default_tx_uuid "8f4f1203-6f3d-4f9c-9e3b-7f4a4f0f1000"
  @default_local_name "meshx"
  @default_mtu 185

  @impl MeshxTransportBLE.Bridge
  def start_link(opts) do
    command = Keyword.get(opts, :command, default_command())
    args = Keyword.get(opts, :args, command_args(opts))

    opts
    |> Keyword.take([:event_target, :command_timeout_ms])
    |> Keyword.put(:command, command)
    |> Keyword.put(:args, args)
    |> Keyword.put(:command_ack?, true)
    |> PortBridge.start_link()
  end

  @impl MeshxTransportBLE.Bridge
  def send_frame(bridge, peer_id, frame, opts \\ []) do
    PortBridge.send_frame(bridge, peer_id, frame, opts)
  end

  @impl MeshxTransportBLE.Bridge
  def broadcast_frame(bridge, frame, opts \\ []) do
    PortBridge.broadcast_frame(bridge, frame, opts)
  end

  @doc """
  Runs the bundled BlueZ backend health check.

  The health check verifies that the selected Linux adapter exists and exposes
  the BlueZ interfaces MeshX needs for discovery, GATT service registration,
  and LE advertising. It is intended for release checks on target hosts before
  starting a production BLE node.
  """
  @spec health_check(keyword()) ::
          {:ok, String.t()}
          | {:error, :timeout | {:exit_status, non_neg_integer(), String.t()} | {:exec, term()}}
  def health_check(opts \\ []) do
    command = Keyword.get(opts, :command, default_command())
    args = Keyword.get(opts, :args, command_args(opts)) ++ ["--health-check"]
    timeout = Keyword.get(opts, :timeout, 30_000)

    case run_command(command, args, timeout) do
      {:ok, {output, 0}} -> {:ok, String.trim(output)}
      {:ok, {output, status}} -> {:error, {:exit_status, status, String.trim(output)}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp run_command(command, args, timeout) do
    task =
      Task.async(fn ->
        try do
          {:ok, System.cmd(command, args, stderr_to_stdout: true)}
        rescue
          error in ErlangError -> {:error, {:exec, error.original}}
        end
      end)

    case Task.yield(task, timeout) || Task.shutdown(task, :brutal_kill) do
      {:ok, result} -> result
      nil -> {:error, :timeout}
    end
  rescue
    error in ErlangError -> {:error, {:exec, error.original}}
  end

  @doc false
  @spec default_command() :: String.t()
  def default_command do
    case :code.priv_dir(:meshx_transport_ble) do
      {:error, _reason} ->
        Path.expand("../../priv/bin/meshx_bluez_bridge", __DIR__)

      priv_dir ->
        priv_dir
        |> to_string()
        |> Path.join("bin/meshx_bluez_bridge")
    end
  end

  @doc false
  @spec command_args(keyword()) :: [String.t()]
  def command_args(opts) do
    []
    |> put_arg("--adapter", Keyword.get(opts, :adapter))
    |> put_arg("--service-uuid", Keyword.get(opts, :service_uuid, @default_service_uuid))
    |> put_arg("--rx-uuid", Keyword.get(opts, :rx_uuid, @default_rx_uuid))
    |> put_arg("--tx-uuid", Keyword.get(opts, :tx_uuid, @default_tx_uuid))
    |> put_arg("--local-name", Keyword.get(opts, :local_name, @default_local_name))
    |> put_arg("--mtu", Keyword.get(opts, :mtu, @default_mtu))
    |> maybe_put_flag("--no-scan", Keyword.get(opts, :scan?, true) == false)
  end

  defp put_arg(args, _name, nil), do: args
  defp put_arg(args, name, value), do: args ++ [name, to_string(value)]

  defp maybe_put_flag(args, name, true), do: args ++ [name]
  defp maybe_put_flag(args, _name, false), do: args
end
