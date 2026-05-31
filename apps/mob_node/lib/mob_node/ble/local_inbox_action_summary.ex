defmodule Mob.Node.BLE.LocalInboxActionSummary do
  @moduledoc """
  Product/API summary for advertisement-only local inbox action state.

  The summary combines nearby-message counts, resolution-status counts,
  and optional fetch-intent projection. It does not dispatch fetches,
  open transports, route, persist, ACK, retry, encrypt, or run background
  work.
  """

  alias Mob.Node.BLE.{
    LocalInboxFetchIntents,
    LocalInboxQuery,
    LocalInboxResolution
  }

  @resolution_states [
    :full_envelope_present,
    :already_known,
    :needs_fetch,
    :stale_needs_fetch,
    :unresolvable
  ]

  @spec summarize(map(), keyword()) :: {:ok, map()} | {:error, term()}
  def summarize(%{} = snapshot, opts \\ []) do
    resolution_statuses = resolution_statuses(snapshot)

    with {:ok, fetch_intents} <-
           maybe_fetch_intents(snapshot, Keyword.get(opts, :fetch_intents, false)) do
      {:ok,
       %{
         nearby_counts: LocalInboxQuery.counts_by_state(snapshot),
         resolution_counts: resolution_counts(resolution_statuses),
         fetch_intent_count: length(fetch_intents),
         fetch_intents: fetch_intents,
         blockers: blockers(resolution_statuses, fetch_intents),
         next_actions: next_actions(resolution_statuses, fetch_intents)
       }}
    end
  end

  defp maybe_fetch_intents(_snapshot, false), do: {:ok, []}

  defp maybe_fetch_intents(snapshot, opts) when is_list(opts),
    do: LocalInboxFetchIntents.from_snapshot(snapshot, opts)

  defp maybe_fetch_intents(_snapshot, _opts), do: {:error, :invalid_fetch_intent_options}

  defp resolution_statuses(%{resolution_statuses: statuses}) when is_list(statuses), do: statuses
  defp resolution_statuses(%{} = snapshot), do: LocalInboxResolution.statuses(snapshot)

  defp resolution_counts(statuses) do
    counts = Enum.frequencies_by(statuses, & &1.resolution_state)

    Map.new(@resolution_states, fn state -> {state, Map.get(counts, state, 0)} end)
  end

  defp blockers(statuses, fetch_intents) do
    []
    |> maybe_add_blocker(:fetch_transport_not_validated, fetch_needed?(statuses))
    |> maybe_add_blocker(:fetch_intents_not_dispatched, fetch_intents != [])
    |> maybe_add_blocker(:unresolvable_refs_present, unresolvable?(statuses))
    |> Enum.reverse()
  end

  defp next_actions(statuses, fetch_intents) do
    []
    |> maybe_add_action(
      :show_full_messages,
      resolution_count(statuses, :full_envelope_present) > 0
    )
    |> maybe_add_action(:show_unresolved_refs, fetch_needed?(statuses))
    |> maybe_add_action(:review_fetch_intents, fetch_intents != [])
    |> maybe_add_action(:review_unresolvable_refs, unresolvable?(statuses))
    |> Enum.reverse()
  end

  defp fetch_needed?(statuses) do
    Enum.any?(statuses, &(&1.resolution_state in [:needs_fetch, :stale_needs_fetch]))
  end

  defp unresolvable?(statuses), do: Enum.any?(statuses, &(&1.resolution_state == :unresolvable))

  defp resolution_count(statuses, state),
    do: Enum.count(statuses, &(&1.resolution_state == state))

  defp maybe_add_blocker(blockers, blocker, true), do: [blocker | blockers]
  defp maybe_add_blocker(blockers, _blocker, false), do: blockers

  defp maybe_add_action(actions, action, true), do: [action | actions]
  defp maybe_add_action(actions, _action, false), do: actions
end
