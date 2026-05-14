defmodule MeshxMobileApp.BLE.Lifecycle do
  @moduledoc """
  Single lifecycle FSM shared by iOS and Android bridge implementations.

  One enum, not two — the bridge protocol forbids platform-specific state
  names. Transitions are validated by `transition/2` so an out-of-order
  state report from the native side fails fast rather than poisoning the
  session.

  States:

    * `:idle` — bridge module loaded, no BLE activity.
    * `:starting` — `start_scan/start_advertising` accepted; waiting for OS.
    * `:scanning` — discovering peers.
    * `:advertising` — broadcasting our local advertisement.
    * `:scanning_and_advertising` — both at once (BLE central + peripheral).
    * `:stopping` — `stop/1` accepted; waiting for OS to drain.
    * `:error` — terminal-ish state; further work requires explicit reset.
  """

  @states [
    :idle,
    :starting,
    :scanning,
    :advertising,
    :scanning_and_advertising,
    :stopping,
    :error
  ]

  @type state ::
          :idle
          | :starting
          | :scanning
          | :advertising
          | :scanning_and_advertising
          | :stopping
          | :error

  @spec states() :: [state()]
  def states, do: @states

  @spec valid_state?(term()) :: boolean()
  def valid_state?(state) when state in @states, do: true
  def valid_state?(_), do: false

  @doc """
  Validates a state transition.

  Returns `{:ok, to}` on a permitted edge, `{:error, {:invalid_transition, from, to}}`
  otherwise. `:error` is reachable from anywhere; `:idle` is reachable from
  any terminal-ish state via `:stopping`.
  """
  @spec transition(state(), state()) ::
          {:ok, state()} | {:error, {:invalid_transition, state(), state()}}
  def transition(from, to) when from in @states and to in @states do
    if allowed?(from, to) do
      {:ok, to}
    else
      {:error, {:invalid_transition, from, to}}
    end
  end

  defp allowed?(_from, :error), do: true
  defp allowed?(:idle, :starting), do: true
  defp allowed?(:starting, :scanning), do: true
  defp allowed?(:starting, :advertising), do: true
  defp allowed?(:starting, :scanning_and_advertising), do: true
  defp allowed?(:scanning, :scanning_and_advertising), do: true
  defp allowed?(:advertising, :scanning_and_advertising), do: true
  defp allowed?(:scanning_and_advertising, :scanning), do: true
  defp allowed?(:scanning_and_advertising, :advertising), do: true

  defp allowed?(state, :stopping)
       when state in [:scanning, :advertising, :scanning_and_advertising, :starting],
       do: true

  defp allowed?(:stopping, :idle), do: true
  defp allowed?(:error, :stopping), do: true
  defp allowed?(state, state), do: true
  defp allowed?(_, _), do: false
end
