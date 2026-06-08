defmodule Mob.Node.MeshStatus do
  @moduledoc """
  UI-friendly mesh connectivity summary for home and chat screens.

  Use `readiness/1` for a single banner state; `line/0` remains for compact
  technical detail (transport + bridge).
  """

  @type state :: :not_ready | :radio_off | :listening | :ready

  @type session_hint :: %{
          optional(:mode) => :scan | :advertise,
          optional(:status) => String.t(),
          optional(:peer_id) => String.t() | nil
        }

  @type readiness :: %{
          state: state(),
          headline: String.t(),
          detail: String.t(),
          ready?: boolean(),
          chat_enabled?: boolean()
        }

  @active_radio_statuses ["Scanning", "Advertising"]
  @connected_statuses ["Device connected", "Secure peer connected"]

  @doc """
  Returns a single readiness map for banners and send gating.

  Options:

    * `:session` — `%{status:, mode:, peer_id:}` from `Mob.Node.Session` snapshot.
      When omitted, uses `Application.get_env(:mob_node, :mesh_session_hint)` if set.
  """
  @spec readiness(keyword()) :: readiness()
  def readiness(opts \\ []) do
    session = Keyword.get(opts, :session) || Application.get_env(:mob_node, :mesh_session_hint)
    transport_ok = transport_ready?()
    bridge_ok = bridge_active?()

    cond do
      not transport_ok or not bridge_ok ->
        not_ready_readiness(transport_ok, bridge_ok)

      session == nil ->
        radio_off_readiness("Return to Home and tap Start Scanning or Start Advertising.")

      session.status in ["Waiting for Bluetooth", "Stopped"] ->
        radio_off_readiness(start_hint(session.mode))

      session.status in @active_radio_statuses ->
        listening_readiness(session)

      session.status in @connected_statuses ->
        ready_readiness(session, "Peer linked — chat is ready.")

      true ->
        ready_readiness(session, "Mesh is up — open chat when both devices are on the air.")
    end
  end

  @doc "True when the user has started BLE and core mesh wiring is up."
  @spec ready_for_chat?(readiness() | keyword()) :: boolean()
  def ready_for_chat?(%{chat_enabled?: enabled}), do: enabled

  def ready_for_chat?(opts) when is_list(opts), do: opts |> readiness() |> ready_for_chat?()

  @doc "Compact technical line (transport · bridge)."
  @spec line() :: String.t()
  def line do
    [transport_part(), ble_part()]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join(" · ")
  end

  @doc false
  @spec publish_session_hint(session_hint()) :: :ok
  def publish_session_hint(hint) when is_map(hint) do
    Application.put_env(:mob_node, :mesh_session_hint, Map.take(hint, [:mode, :status, :peer_id]))
    :ok
  end

  defp not_ready_readiness(transport_ok, bridge_ok) do
    detail =
      cond do
        not transport_ok and not bridge_ok ->
          "Restart the app. Mesh transport and Bluetooth bridge did not start."

        not transport_ok ->
          "Restart the app so mesh transport can attach to the router."

        true ->
          "Bluetooth bridge is inactive — check that the BLE plugin loaded on this build."
      end

    %{
      state: :not_ready,
      headline: "Not ready for mesh chat",
      detail: detail,
      ready?: false,
      chat_enabled?: false
    }
  end

  defp radio_off_readiness(detail) do
    %{
      state: :radio_off,
      headline: "Bluetooth idle",
      detail: detail,
      ready?: false,
      chat_enabled?: false
    }
  end

  defp listening_readiness(session) do
    mode_label = if session.mode == :advertise, do: "advertising", else: "scanning"

    %{
      state: :listening,
      headline: "Waiting for nearby device",
      detail:
        "You are #{mode_label}. On the other phone: pick the opposite mode, tap Start, then open #general.",
      ready?: false,
      chat_enabled?: true
    }
  end

  defp ready_readiness(session, detail) do
    peer = session.peer_id || "none yet"

    %{
      state: :ready,
      headline: "Ready for #general",
      detail: "#{detail} Peer: #{peer}.",
      ready?: true,
      chat_enabled?: true
    }
  end

  defp start_hint(:advertise),
    do: "Tap Start Advertising so the other device can find you while scanning."

  defp start_hint(_), do: "Tap Start Scanning so you can hear nearby advertisers."

  defp transport_ready? do
    case Application.get_env(:mob_node, :ble_transport_pid) do
      pid when is_pid(pid) -> Process.alive?(pid)
      _ -> false
    end
  end

  defp bridge_active? do
    case Application.get_env(:mob_node, :ble_adapter) do
      mod when mod in [Mob.Node.NativeBridge.IOS, Mob.Node.NativeBridge.Android] -> true
      _ -> false
    end
  end

  defp transport_part do
    if transport_ready?(), do: "Mesh transport ready", else: "Mesh transport off"
  end

  defp ble_part do
    if bridge_active?(), do: "Bluetooth bridge active", else: "Bluetooth bridge inactive"
  end
end
