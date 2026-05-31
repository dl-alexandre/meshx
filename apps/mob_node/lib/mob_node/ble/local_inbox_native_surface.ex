defmodule Mob.Node.BLE.LocalInboxNativeSurface do
  @moduledoc """
  Native-control view model for the advertisement-only local inbox.

  This module turns `LocalInboxProductSurface` into stable rows, state
  filters, sort choices, and detail panel data that a native Mob screen can
  render without knowing inbox internals. It does not resolve beacon refs,
  fetch envelopes, route, persist, ACK, retry, encrypt, scan, advertise, or
  run background work.
  """

  alias Mob.Node.BLE.{
    LocalInboxProductSurface,
    LocalInboxStateCopy,
    LocalInboxView,
    LocalTrustPolicy
  }

  @sort_options [
    recent_first: {"Recent", "Newest observations first"},
    state_then_recent: {"State", "Full messages, refs, gossip, then stale"},
    strongest_rssi: {"Signal", "Strongest signal first"},
    payload_kind_then_recent: {"Kind", "Grouped by payload kind, then newest"},
    oldest_first: {"Oldest", "Oldest observations first"}
  ]

  @state_filters [:all, :full_message, :unresolved_ref, :gossiped_ref, :stale_ref]
  @default_state_filter :all
  @default_sort :state_then_recent

  @type state_filter :: :all | LocalInboxView.Item.state()
  @type row :: %{
          message_key: binary(),
          state: LocalInboxView.Item.state(),
          title: binary(),
          subtitle: binary(),
          meta: binary(),
          badge: binary(),
          state_summary: binary(),
          next_action: binary(),
          severity: LocalInboxStateCopy.severity(),
          selected?: boolean(),
          stale?: boolean(),
          unresolved?: boolean(),
          trust_summary: binary(),
          trusted_message?: boolean(),
          delivery_claim_allowed?: boolean(),
          blocked_claims: [binary()],
          source_device_ids: [binary()]
        }

  @type t :: %{
          title: binary(),
          empty?: boolean(),
          empty_label: binary(),
          summary_line: binary(),
          filter_summary: binary(),
          sort_summary: binary(),
          selected_state: state_filter(),
          selected_sort: atom(),
          state_filters: [map()],
          sort_options: [map()],
          state_copy: [map()],
          rows: [row()],
          sections: [map()],
          detail: map() | nil,
          warnings: [binary()]
        }

  @spec build(map() | nil, keyword()) :: t()
  def build(snapshot, opts \\ []) do
    selected_state =
      opts
      |> Keyword.get(:selected_state, @default_state_filter)
      |> normalize_state_filter()

    selected_sort =
      opts
      |> Keyword.get(:sort, @default_sort)
      |> normalize_sort()

    detail_message_key = Keyword.get(opts, :detail_message_key)

    surface =
      snapshot
      |> LocalInboxProductSurface.build(
        [
          states: states_filter(selected_state),
          sort: selected_sort,
          detail_message_key: detail_message_key
        ] ++ freshness_opts(opts)
      )

    trust_decisions = trust_decisions_by_key(surface.trust_evidence)
    rows = rows(surface.sections, detail_message_key, trust_decisions)

    %{
      title: surface.title,
      empty?: rows == [],
      empty_label: empty_label(surface, selected_state),
      summary_line: summary_line(surface),
      filter_summary: filter_summary(selected_state, rows),
      sort_summary: sort_summary(selected_sort),
      selected_state: selected_state,
      selected_sort: selected_sort,
      state_filters: state_filters(surface, selected_state),
      sort_options: sort_options(selected_sort),
      state_copy: surface.state_copy,
      rows: rows,
      sections: sections(surface.sections, detail_message_key, trust_decisions),
      detail: detail(surface.selected_detail, trust_decisions),
      warnings: surface.notes
    }
  end

  defp states_filter(:all), do: :all
  defp states_filter(state) when is_atom(state), do: [state]

  defp normalize_state_filter(state) when state in @state_filters, do: state
  defp normalize_state_filter(_state), do: @default_state_filter

  defp normalize_sort(sort) do
    if Keyword.has_key?(@sort_options, sort), do: sort, else: @default_sort
  end

  defp freshness_opts(opts) do
    opts
    |> Keyword.take([:now, :stale_after_ms])
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
  end

  defp state_filters(surface, selected_state) do
    all_count =
      surface.counts_by_state
      |> Map.values()
      |> Enum.sum()

    [
      %{
        state: :all,
        label: "All",
        count: all_count,
        selected?: selected_state == :all
      }
      | Enum.map(surface.state_order, fn state ->
          %{
            state: state,
            label: LocalInboxProductSurface.state_label(state),
            short_label: state |> LocalInboxStateCopy.for_state() |> Map.fetch!(:short_label),
            count: Map.fetch!(surface.counts_by_state, state),
            selected?: selected_state == state
          }
        end)
    ]
  end

  defp summary_line(surface) do
    counts = surface.counts_by_state
    full = Map.fetch!(counts, :full_message)
    unresolved = Map.fetch!(counts, :unresolved_ref)
    gossiped = Map.fetch!(counts, :gossiped_ref)
    stale = Map.fetch!(counts, :stale_ref)
    total = full + unresolved + gossiped + stale

    "#{total} nearby | full #{full} | refs #{unresolved} | gossip #{gossiped} | stale #{stale}"
  end

  defp empty_label(_surface, :all), do: "No nearby messages"

  defp empty_label(surface, state) do
    surface.sections
    |> Enum.find(&(&1.state == state))
    |> case do
      %{empty_label: label} -> label
      _missing -> "No nearby messages"
    end
  end

  defp sort_options(selected_sort) do
    Enum.map(@sort_options, fn {sort, {label, description}} ->
      %{sort: sort, label: label, description: description, selected?: selected_sort == sort}
    end)
  end

  defp filter_summary(:all, rows), do: "Showing all nearby observations (#{length(rows)})."

  defp filter_summary(state, rows) do
    label =
      state
      |> LocalInboxProductSurface.state_label()
      |> String.downcase()

    "Showing #{label} only (#{length(rows)})."
  end

  defp sort_summary(selected_sort) do
    case Keyword.fetch(@sort_options, selected_sort) do
      {:ok, {_label, description}} -> description
      :error -> "Custom ordering"
    end
  end

  defp sections(surface_sections, detail_message_key, trust_decisions) do
    Enum.map(surface_sections, fn section ->
      %{
        state: section.state,
        label: section.label,
        count: section.count,
        empty_label: section.empty_label,
        rows: Enum.map(section.items, &row(&1, detail_message_key, trust_decisions))
      }
    end)
  end

  defp rows(sections, detail_message_key, trust_decisions) do
    sections
    |> Enum.flat_map(& &1.items)
    |> Enum.map(&row(&1, detail_message_key, trust_decisions))
  end

  defp row(%LocalInboxView.Item{} = item, detail_message_key, trust_decisions) do
    copy = LocalInboxStateCopy.for_state(item.state)
    trust = trust_decision(item, trust_decisions)

    %{
      message_key: item.message_key,
      state: item.state,
      title: title(item),
      subtitle: subtitle(item),
      meta: meta(item),
      badge: copy.badge,
      state_summary: copy.summary,
      next_action: copy.next_action,
      severity: copy.severity,
      selected?: item.message_key == detail_message_key,
      stale?: item.state == :stale_ref,
      unresolved?: item.state in [:unresolved_ref, :gossiped_ref, :stale_ref],
      trust_summary: trust_summary(trust),
      trusted_message?: trust.trusted_message?,
      delivery_claim_allowed?: trust.delivery_claim_allowed?,
      blocked_claims: copy.blocked_claims,
      source_device_ids: item.source_device_ids
    }
  end

  defp detail(nil, _trust_decisions), do: nil

  defp detail({:error, :not_found}, _trust_decisions),
    do: %{status: :not_found, title: "Message not found"}

  defp detail({:ok, %LocalInboxView.Item{} = item}, trust_decisions) do
    copy = LocalInboxStateCopy.for_state(item.state)
    trust = trust_decision(item, trust_decisions)

    %{
      status: :selected,
      message_key: item.message_key,
      state: item.state,
      state_label: copy.label,
      detail_title: copy.detail_title,
      title: title(item),
      payload_kind: item.payload_kind,
      envelope_version: item.envelope_version,
      first_seen_at: item.first_seen_at,
      last_seen_at: item.last_seen_at,
      seen_count: item.seen_count,
      source_device_ids: item.source_device_ids,
      last_rssi: item.last_rssi,
      message_id: item.message_id,
      message_id_hash: item.message_id_hash,
      sender_peer_id: item.sender_peer_id,
      sender_peer_hash: item.sender_peer_hash,
      recipient_peer_id: item.recipient_peer_id,
      observed_via: item.observed_via,
      trust_summary: trust_summary(trust),
      trusted_message?: trust.trusted_message?,
      delivery_claim_allowed?: trust.delivery_claim_allowed?,
      required_before_trusted: trust.required_before_trusted,
      trust_reasons: trust.reasons,
      detail_lines: detail_lines(item, copy, trust),
      limitation: copy.limitation,
      next_action: copy.next_action,
      severity: copy.severity,
      blocked_claims: copy.blocked_claims
    }
  end

  defp title(%LocalInboxView.Item{state: :full_message, sender_peer_id: sender}) do
    "Full message from #{sender || "unknown peer"}"
  end

  defp title(%LocalInboxView.Item{state: state, message_id_hash: hash}) do
    "#{LocalInboxProductSurface.state_label(state)} #{short_hash(hash)}"
  end

  defp subtitle(%LocalInboxView.Item{state: :full_message, recipient_peer_id: nil}) do
    "Broadcast full envelope"
  end

  defp subtitle(%LocalInboxView.Item{state: :full_message, recipient_peer_id: recipient}) do
    "Full envelope to #{recipient}"
  end

  defp subtitle(%LocalInboxView.Item{state: :gossiped_ref}) do
    "Beacon ref observed through advert gossip"
  end

  defp subtitle(%LocalInboxView.Item{state: :stale_ref}) do
    "Stale beacon ref; full message is not available"
  end

  defp subtitle(%LocalInboxView.Item{state: :unresolved_ref}) do
    "Legacy beacon ref; needs future fetch transport"
  end

  defp meta(%LocalInboxView.Item{} = item) do
    "kind #{item.payload_kind || "unknown"} | seen #{item.seen_count} | rssi #{item.last_rssi || "unknown"}"
  end

  defp detail_lines(%LocalInboxView.Item{} = item, copy, trust) do
    [
      copy.detail_title,
      "State: #{copy.label}",
      identifier_line(item),
      sender_line(item),
      recipient_line(item),
      "Kind: #{item.payload_kind || "unknown"}",
      "Envelope v#{item.envelope_version || "unknown"}",
      "First seen: #{item.first_seen_at}",
      "Last seen: #{item.last_seen_at}",
      "Seen: #{item.seen_count}",
      "RSSI: #{item.last_rssi || "unknown"}",
      "Sources: #{source_devices(item.source_device_ids)}",
      "Observed via: #{observed_via(item.observed_via)}",
      "Trust: #{trust_summary(trust)}",
      "Required before trusted: #{required_before_trusted(trust.required_before_trusted)}",
      copy.limitation,
      "Blocked claims: #{Enum.join(copy.blocked_claims, ", ")}",
      "Next: #{copy.next_action}"
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp identifier_line(%LocalInboxView.Item{state: :full_message, message_id: message_id}) do
    "Message ID: #{short_hash(message_id)}"
  end

  defp identifier_line(%LocalInboxView.Item{message_id_hash: message_id_hash}) do
    "Message hash: #{short_hash(message_id_hash)}"
  end

  defp sender_line(%LocalInboxView.Item{state: :full_message, sender_peer_id: sender_peer_id}) do
    "Sender: #{sender_peer_id || "unknown peer"}"
  end

  defp sender_line(%LocalInboxView.Item{sender_peer_hash: sender_peer_hash}) do
    "Sender hash: #{short_hash(sender_peer_hash)}"
  end

  defp recipient_line(%LocalInboxView.Item{state: :full_message, recipient_peer_id: nil}) do
    "Recipient: broadcast"
  end

  defp recipient_line(%LocalInboxView.Item{
         state: :full_message,
         recipient_peer_id: recipient_peer_id
       }) do
    "Recipient: #{recipient_peer_id}"
  end

  defp recipient_line(%LocalInboxView.Item{}), do: nil

  defp source_devices([]), do: "unknown"
  defp source_devices(source_device_ids), do: Enum.join(source_device_ids, ", ")

  defp observed_via([]), do: "direct advertisement"
  defp observed_via([:unknown]), do: "direct advertisement"

  defp observed_via(observed_via) do
    observed_via
    |> Enum.map(&to_string/1)
    |> Enum.sort()
    |> Enum.join(", ")
  end

  defp short_hash(nil), do: "unknown"

  defp short_hash(hash) when is_binary(hash) do
    hash
    |> Base.encode16(case: :lower)
    |> binary_part(0, min(byte_size(hash) * 2, 8))
  end

  defp trust_decisions_by_key(trust_evidence) when is_list(trust_evidence) do
    trust_evidence
    |> LocalTrustPolicy.decisions()
    |> Map.new(&{&1.message_key, &1})
  end

  defp trust_decisions_by_key(_trust_evidence), do: %{}

  defp trust_decision(%LocalInboxView.Item{} = item, trust_decisions) do
    Map.get_lazy(trust_decisions, item.message_key, fn ->
      item
      |> fallback_trust_evidence()
      |> LocalTrustPolicy.decide()
    end)
  end

  defp fallback_trust_evidence(%LocalInboxView.Item{} = item) do
    item
    |> Mob.Node.BLE.LocalInboxTrust.classify()
  end

  defp trust_summary(%LocalTrustPolicy.Decision{presentation: :local_unsigned_message}) do
    "Unsigned local observation"
  end

  defp trust_summary(%LocalTrustPolicy.Decision{presentation: :local_untrusted_reference}) do
    "Untrusted hash reference"
  end

  defp required_before_trusted(required) do
    required
    |> Enum.map(&Atom.to_string/1)
    |> Enum.join(", ")
  end
end
