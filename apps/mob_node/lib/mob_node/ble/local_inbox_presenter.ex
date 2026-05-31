defmodule Mob.Node.BLE.LocalInboxPresenter do
  @moduledoc """
  Compact text presenter for the advertisement-only local inbox.

  This is a UI adapter over existing read models. It does not resolve
  beacon refs, fetch envelopes, route, persist, ACK, retry, encrypt, or
  run background work.
  """

  alias Mob.Node.BLE.LocalInboxProductSurface

  @spec render_text(map() | nil, keyword()) :: binary()
  def render_text(snapshot, opts \\ [])

  def render_text(nil, _opts), do: "No nearby messages"

  def render_text(%{} = snapshot, opts) do
    surface =
      snapshot
      |> ensure_nearby_messages()
      |> LocalInboxProductSurface.build(Keyword.put_new(opts, :sort, :state_then_recent))

    if empty?(surface) do
      "No nearby messages"
    else
      surface
      |> header_lines()
      |> Kernel.++(section_lines(surface))
      |> Kernel.++(detail_lines(surface))
      |> Enum.join("\n")
    end
  end

  defp ensure_nearby_messages(%{nearby_messages: nearby_messages} = snapshot)
       when is_list(nearby_messages),
       do: snapshot

  defp ensure_nearby_messages(%{} = snapshot), do: Map.put(snapshot, :nearby_messages, [])

  defp empty?(%{sections: sections}) do
    Enum.all?(sections, &(&1.count == 0))
  end

  defp header_lines(%{action_summary: summary}) when is_map(summary) do
    [
      "Nearby Messages",
      counts_line(summary),
      resolution_line(summary),
      blockers_line(summary)
    ]
    |> Enum.reject(&(&1 == ""))
  end

  defp header_lines(surface) do
    ["Nearby Messages", counts_fallback_line(surface)]
  end

  defp counts_line(%{nearby_counts: counts}) do
    "Full #{counts.full_message} | Unresolved refs #{counts.unresolved_ref} | Gossiped refs #{counts.gossiped_ref} | Stale refs #{counts.stale_ref}"
  end

  defp resolution_line(%{resolution_counts: counts}) do
    "Resolution full #{counts.full_envelope_present} | known #{counts.already_known} | needs fetch #{counts.needs_fetch} | stale fetch #{counts.stale_needs_fetch} | unresolvable #{counts.unresolvable}"
  end

  defp blockers_line(%{blockers: []}), do: ""

  defp blockers_line(%{blockers: blockers}) do
    "Blocked: " <> Enum.map_join(blockers, ", ", &Atom.to_string/1)
  end

  defp counts_fallback_line(%{counts_by_state: counts}) do
    "Full #{counts.full_message} | Unresolved refs #{counts.unresolved_ref} | Gossiped refs #{counts.gossiped_ref} | Stale refs #{counts.stale_ref}"
  end

  defp section_lines(%{sections: sections} = surface) do
    sections
    |> Enum.flat_map(fn section ->
      if section.count == 0 do
        []
      else
        [
          section.label <> " - " <> section.description
          | Enum.map(section.items, &("  " <> item_line(&1, surface)))
        ]
      end
    end)
  end

  defp detail_lines(%{selected_detail_summary: nil}), do: []

  defp detail_lines(%{selected_detail_summary: summary}) when is_map(summary) do
    [
      "Selected: #{summary.title}",
      "  state=#{summary.state} badge=#{summary.badge} severity=#{summary.severity}",
      "  limit=#{summary.limitation}",
      "  next=#{summary.next_action}",
      "  blocked=#{Enum.join(summary.blocked_claims, "; ")}"
    ]
  end

  defp item_line(item, surface) do
    [
      state_label(item),
      item_id(item),
      "kind=#{item.payload_kind}",
      resolution_label(item, surface),
      trust_label(item, surface),
      "seen=#{item.seen_count}",
      "rssi=#{item.last_rssi}",
      "src=#{length(item.source_device_ids)}"
    ]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join(" ")
  end

  defp state_label(%{state: :full_message}), do: "full"
  defp state_label(%{state: :unresolved_ref}), do: "unresolved-ref"
  defp state_label(%{state: :gossiped_ref}), do: "gossiped-ref"
  defp state_label(%{state: :stale_ref}), do: "stale-ref"

  defp item_id(%{message_id: message_id}) when is_binary(message_id), do: short_hash(message_id)
  defp item_id(%{message_id_hash: hash}) when is_binary(hash), do: short_hash(hash)
  defp item_id(%{message_key: key}) when is_binary(key), do: String.slice(key, 0, 12)

  defp resolution_label(%{message_key: key}, surface) do
    surface
    |> Map.get(:resolution_statuses, [])
    |> Enum.find(&(Map.get(&1, :message_key) == key))
    |> case do
      nil ->
        nil

      status ->
        "resolve=#{Map.get(status, :resolution_state)} fetch=#{Map.get(status, :fetch_transport_state)}"
    end
  end

  defp trust_label(%{message_key: key}, snapshot) do
    snapshot
    |> Map.get(:trust_evidence, [])
    |> Enum.find(&(Map.get(&1, :message_key) == key))
    |> case do
      nil -> nil
      evidence -> "trust=#{Map.get(evidence, :trust_state)}"
    end
  end

  defp short_hash(value) when is_binary(value) do
    value
    |> Base.encode16(case: :lower)
    |> String.slice(0, 12)
  end
end
