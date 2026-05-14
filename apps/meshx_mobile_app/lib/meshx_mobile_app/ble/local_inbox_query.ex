defmodule MeshxMobileApp.BLE.LocalInboxQuery do
  @moduledoc """
  Pure query helpers for advertisement-only local inbox snapshots.

  This module gives product surfaces a stable way to filter, sort, and
  select nearby-message details without changing the canonical inbox or
  adding transport, routing, persistence, crypto, ACK, retry, fetch, or
  background behavior.
  """

  alias MeshxMobileApp.BLE.LocalInboxView

  @sorts [
    :recent_first,
    :oldest_first,
    :state_then_recent,
    :payload_kind_then_recent,
    :strongest_rssi
  ]

  @type sort ::
          :recent_first
          | :oldest_first
          | :state_then_recent
          | :payload_kind_then_recent
          | :strongest_rssi

  @type opts :: [
          states: [LocalInboxView.Item.state()] | :all,
          payload_kinds: [binary()] | :all,
          source_device_id: binary(),
          observed_via: atom(),
          now: integer(),
          stale_after_ms: pos_integer(),
          sort: sort(),
          limit: pos_integer()
        ]

  @spec list(map(), opts()) :: [LocalInboxView.Item.t()]
  def list(%{} = snapshot, opts \\ []) do
    sort = opts |> Keyword.get(:sort, :recent_first) |> normalize_sort()

    snapshot
    |> nearby_messages(opts)
    |> filter_states(Keyword.get(opts, :states, :all))
    |> filter_payload_kinds(Keyword.get(opts, :payload_kinds, :all))
    |> filter_source_device(Keyword.get(opts, :source_device_id))
    |> filter_observed_via(Keyword.get(opts, :observed_via))
    |> sort(sort)
    |> limit(Keyword.get(opts, :limit))
  end

  @spec normalize_sort(atom()) :: sort()
  def normalize_sort(sort) when sort in @sorts, do: sort
  def normalize_sort(_sort), do: :recent_first

  defp nearby_messages(snapshot, opts) do
    if Keyword.has_key?(opts, :now) or Keyword.has_key?(opts, :stale_after_ms) do
      view_opts = Keyword.take(opts, [:now, :stale_after_ms])
      LocalInboxView.nearby_messages(snapshot, view_opts)
    else
      nearby_messages(snapshot)
    end
  end

  defp nearby_messages(%{nearby_messages: nearby_messages}) when is_list(nearby_messages) do
    nearby_messages
  end

  defp nearby_messages(%{} = snapshot), do: LocalInboxView.nearby_messages(snapshot)

  @spec detail(map(), binary()) :: {:ok, LocalInboxView.Item.t()} | {:error, :not_found}
  def detail(%{} = snapshot, message_key, opts \\ []) when is_binary(message_key) do
    snapshot
    |> list(opts)
    |> Enum.find(&(&1.message_key == message_key))
    |> case do
      %LocalInboxView.Item{} = item -> {:ok, item}
      nil -> {:error, :not_found}
    end
  end

  @spec counts_by_state(map()) :: %{LocalInboxView.Item.state() => non_neg_integer()}
  def counts_by_state(%{} = snapshot, opts \\ []) do
    snapshot
    |> list(opts)
    |> Enum.frequencies_by(& &1.state)
    |> Map.merge(
      %{
        full_message: 0,
        unresolved_ref: 0,
        gossiped_ref: 0,
        stale_ref: 0
      },
      fn _state, count, 0 -> count end
    )
  end

  defp filter_states(items, :all), do: items

  defp filter_states(items, states) when is_list(states) do
    Enum.filter(items, &(&1.state in states))
  end

  defp filter_payload_kinds(items, :all), do: items

  defp filter_payload_kinds(items, payload_kinds) when is_list(payload_kinds) do
    Enum.filter(items, &(&1.payload_kind in payload_kinds))
  end

  defp filter_source_device(items, nil), do: items

  defp filter_source_device(items, source_device_id) when is_binary(source_device_id) do
    Enum.filter(items, &(source_device_id in &1.source_device_ids))
  end

  defp filter_observed_via(items, nil), do: items

  defp filter_observed_via(items, observed_via) when is_atom(observed_via) do
    Enum.filter(items, &(observed_via in &1.observed_via))
  end

  defp sort(items, :recent_first) do
    Enum.sort_by(items, &{-&1.last_seen_at, state_rank(&1.state), &1.message_key})
  end

  defp sort(items, :oldest_first) do
    Enum.sort_by(items, &{&1.first_seen_at, state_rank(&1.state), &1.message_key})
  end

  defp sort(items, :state_then_recent) do
    Enum.sort_by(items, &{state_rank(&1.state), -&1.last_seen_at, &1.message_key})
  end

  defp sort(items, :payload_kind_then_recent) do
    Enum.sort_by(
      items,
      &{&1.payload_kind, -&1.last_seen_at, state_rank(&1.state), &1.message_key}
    )
  end

  defp sort(items, :strongest_rssi) do
    Enum.sort_by(items, &{-&1.last_rssi, -&1.last_seen_at, state_rank(&1.state), &1.message_key})
  end

  defp limit(items, nil), do: items
  defp limit(items, limit) when is_integer(limit) and limit > 0, do: Enum.take(items, limit)

  defp state_rank(:full_message), do: 0
  defp state_rank(:unresolved_ref), do: 1
  defp state_rank(:gossiped_ref), do: 2
  defp state_rank(:stale_ref), do: 3
end
