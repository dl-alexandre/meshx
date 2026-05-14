defmodule MeshxMobileApp.BLE.LocalInboxProductSurface do
  @moduledoc """
  UI-ready product surface model for the advertisement-only local inbox.

  This module groups nearby messages into explicit states and carries the
  filter, sort, and detail affordances a native surface needs. It is a
  read model over `LocalInbox.snapshot/1`; it does not resolve beacon refs,
  fetch envelopes, route, persist, ACK, retry, encrypt, or run background
  work.
  """

  alias MeshxMobileApp.BLE.{
    LocalInboxActionSummary,
    LocalInboxQuery,
    LocalInboxStateCopy,
    LocalInboxView
  }

  @states [:full_message, :unresolved_ref, :gossiped_ref, :stale_ref]

  @type detail ::
          nil
          | {:ok, LocalInboxView.Item.t()}
          | {:error, :not_found}

  @type t :: %{
          title: binary(),
          state_order: [LocalInboxView.Item.state()],
          counts_by_state: %{LocalInboxView.Item.state() => non_neg_integer()},
          action_summary: map() | nil,
          resolution_statuses: [map()],
          trust_evidence: [map()],
          active_filters: map(),
          sort: LocalInboxQuery.sort(),
          available_filters: map(),
          state_copy: [map()],
          sections: [map()],
          selected_detail: detail(),
          selected_detail_summary: map() | nil,
          notes: [binary()]
        }

  @spec build(map() | nil, keyword()) :: t()
  def build(snapshot, opts \\ [])

  def build(nil, opts), do: build(%{nearby_messages: []}, opts)

  def build(%{} = snapshot, opts) do
    sort =
      opts
      |> Keyword.get(:sort, :state_then_recent)
      |> normalize_sort(:state_then_recent)

    query_opts = query_opts(opts, sort)
    freshness_opts = Keyword.take(query_opts, [:now, :stale_after_ms])
    items = LocalInboxQuery.list(snapshot, query_opts)
    counts = LocalInboxQuery.counts_by_state(snapshot, freshness_opts)

    selected_detail =
      selected_detail(snapshot, Keyword.get(opts, :detail_message_key), query_opts)

    %{
      title: "Nearby Messages",
      state_order: @states,
      counts_by_state: counts,
      action_summary: action_summary(snapshot),
      resolution_statuses: Map.get(snapshot, :resolution_statuses, []),
      trust_evidence: Map.get(snapshot, :trust_evidence, []),
      active_filters: active_filters(opts),
      sort: sort,
      available_filters: available_filters(snapshot, freshness_opts),
      state_copy: LocalInboxStateCopy.all(),
      sections: sections(items),
      selected_detail: selected_detail,
      selected_detail_summary: selected_detail_summary(selected_detail),
      notes: [
        "Legacy beacon refs are pointers until full-message resolution transport is validated.",
        "Gossiped refs are replay or advert-gossip observations, not guaranteed delivery.",
        "Stale refs remain visible so the UI can show old nearby observations explicitly."
      ]
    }
  end

  @spec state_label(LocalInboxView.Item.state()) :: binary()
  def state_label(state), do: state |> LocalInboxStateCopy.for_state() |> Map.fetch!(:label)

  @spec state_description(LocalInboxView.Item.state()) :: binary()
  def state_description(state),
    do: state |> LocalInboxStateCopy.for_state() |> Map.fetch!(:summary)

  defp query_opts(opts, sort) do
    opts
    |> Keyword.take([
      :states,
      :payload_kinds,
      :source_device_id,
      :observed_via,
      :now,
      :stale_after_ms,
      :limit
    ])
    |> Keyword.put(:sort, sort)
  end

  defp normalize_sort(sort, _default)
       when sort in [
              :recent_first,
              :oldest_first,
              :state_then_recent,
              :payload_kind_then_recent,
              :strongest_rssi
            ],
       do: sort

  defp normalize_sort(_sort, default), do: default

  defp active_filters(opts) do
    %{
      states: Keyword.get(opts, :states, :all),
      payload_kinds: Keyword.get(opts, :payload_kinds, :all),
      source_device_id: Keyword.get(opts, :source_device_id),
      observed_via: Keyword.get(opts, :observed_via)
    }
  end

  defp available_filters(snapshot, opts) do
    items = LocalInboxQuery.list(snapshot, Keyword.merge(opts, sort: :state_then_recent))

    %{
      states: @states,
      payload_kinds: items |> Enum.map(& &1.payload_kind) |> Enum.uniq() |> Enum.sort(),
      source_device_ids:
        items
        |> Enum.flat_map(& &1.source_device_ids)
        |> Enum.uniq()
        |> Enum.sort(),
      observed_via:
        items
        |> Enum.flat_map(& &1.observed_via)
        |> Enum.uniq()
        |> Enum.sort()
    }
  end

  defp sections(items) do
    Enum.map(@states, fn state ->
      section_items = Enum.filter(items, &(&1.state == state))

      %{
        state: state,
        label: state_label(state),
        description: state_description(state),
        count: length(section_items),
        items: section_items,
        empty_label: state |> LocalInboxStateCopy.for_state() |> Map.fetch!(:empty_label)
      }
    end)
  end

  defp selected_detail(_snapshot, nil, _opts), do: nil

  defp selected_detail(snapshot, message_key, opts),
    do: LocalInboxQuery.detail(snapshot, message_key, opts)

  defp selected_detail_summary({:ok, %LocalInboxView.Item{} = item}) do
    copy = LocalInboxStateCopy.for_state(item.state)

    %{
      message_key: item.message_key,
      state: item.state,
      title: copy.detail_title,
      label: copy.label,
      badge: copy.badge,
      severity: copy.severity,
      limitation: copy.limitation,
      next_action: copy.next_action,
      blocked_claims: copy.blocked_claims,
      delivery_claim_allowed?: copy.delivery_claim_allowed?
    }
  end

  defp selected_detail_summary(_detail), do: nil

  defp action_summary(snapshot) do
    case LocalInboxActionSummary.summarize(snapshot) do
      {:ok, summary} -> summary
      {:error, _reason} -> nil
    end
  end
end
