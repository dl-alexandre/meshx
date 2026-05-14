defmodule MeshxMobileApp.BLE.LocalLifecycleManualSession do
  @moduledoc """
  Pure evidence model for foreground/manual BLE validation sessions.

  A manual session records an operator-controlled foreground run: start scan,
  start advertise, observe events, and stop. It is evidence for the current
  lifecycle boundary only. It does not start native services, schedule work,
  restart BLE, run in the background, gossip, route, persist, ACK, retry,
  fetch, encrypt, or authenticate messages.
  """

  @required_actions [
    :operator_start_scan,
    :operator_start_advertise,
    :operator_observe_events,
    :operator_stop
  ]

  @blocked_claims [
    :android_foreground_service_ble,
    :android_background_scan,
    :android_background_advertise,
    :ios_background_scan,
    :ios_background_advertise,
    :background_ble_operation,
    :automatic_ble_restart,
    :scheduled_retry,
    :background_gossip,
    :background_forwarding,
    :background_delivery,
    :guaranteed_delivery
  ]

  @type action :: atom()

  @spec evaluate(map()) :: map()
  def evaluate(session) when is_map(session) do
    actions = normalize_actions(Map.get(session, :actions, Map.get(session, "actions", [])))
    missing = @required_actions -- actions

    %{
      evidence_version: 1,
      boundary: :foreground_manual_lifecycle_session,
      status: status(missing),
      device_id: Map.get(session, :device_id, Map.get(session, "device_id")),
      app_state: normalize_app_state(Map.get(session, :app_state, Map.get(session, "app_state"))),
      actions: actions,
      missing_actions: missing,
      foreground_manual_evidence_complete?: missing == [],
      android_foreground_service_claim_allowed?: false,
      background_ble_claim_allowed?: false,
      restart_claim_allowed?: false,
      scheduled_retry_claim_allowed?: false,
      delivery_claim_allowed?: false,
      blocked_claims: @blocked_claims,
      notes: notes(missing)
    }
  end

  def evaluate(_session) do
    evaluate(%{actions: []})
    |> Map.put(:status, :invalid_session)
    |> Map.put(:missing_actions, @required_actions)
    |> Map.put(:foreground_manual_evidence_complete?, false)
  end

  @spec snapshot([map()]) :: map()
  def snapshot(sessions) when is_list(sessions) do
    evaluations = Enum.map(sessions, &evaluate/1)

    %{
      evidence_version: 1,
      boundary: :foreground_manual_lifecycle_session_snapshot,
      session_count: length(evaluations),
      complete_session_count: Enum.count(evaluations, & &1.foreground_manual_evidence_complete?),
      android_foreground_service_claim_allowed?: false,
      background_ble_claim_allowed?: false,
      restart_claim_allowed?: false,
      scheduled_retry_claim_allowed?: false,
      delivery_claim_allowed?: false,
      sessions: evaluations,
      required_actions: @required_actions,
      blocked_claims: @blocked_claims,
      notes: [
        "Complete manual sessions support foreground/manual lifecycle evidence only.",
        "Background, restart, retry, and delivery claims require separate implementation and hardware evidence."
      ]
    }
  end

  @spec json_snapshot([map()]) :: map()
  def json_snapshot(sessions) when is_list(sessions) do
    sessions
    |> snapshot()
    |> JSON.encode!()
    |> JSON.decode!()
  end

  defp normalize_actions(actions) when is_list(actions) do
    actions
    |> Enum.flat_map(&normalize_action/1)
    |> Enum.uniq()
  end

  defp normalize_actions(_actions), do: []

  defp normalize_action(action) when action in @required_actions, do: [action]
  defp normalize_action("operator_start_scan"), do: [:operator_start_scan]
  defp normalize_action("operator_start_advertise"), do: [:operator_start_advertise]
  defp normalize_action("operator_observe_events"), do: [:operator_observe_events]
  defp normalize_action("operator_stop"), do: [:operator_stop]
  defp normalize_action(_action), do: []

  defp normalize_app_state(state) when state in [:foreground, "foreground"], do: :foreground
  defp normalize_app_state(state) when state in [:background, "background"], do: :background
  defp normalize_app_state(_state), do: :unknown

  defp status([]), do: :complete_foreground_manual
  defp status(_missing), do: :incomplete_foreground_manual

  defp notes([]) do
    [
      "Manual foreground lifecycle evidence is complete for the supplied session.",
      "This does not prove background BLE, restart, retry, or delivery behavior."
    ]
  end

  defp notes(_missing) do
    [
      "Manual foreground lifecycle evidence is incomplete for the supplied session.",
      "Missing actions must be supplied before even foreground/manual evidence is complete."
    ]
  end
end
