defmodule Mob.Node.Chat.ChannelNativeSurface do
  @moduledoc """
  Pure view-model -> screen surface translator for a chat channel.

  Takes a `Mob.Node.Chat.ChannelViewModel` snapshot and produces a
  flat, render-ready struct the `ChatScreen` can iterate over without
  doing any formatting itself. Mirrors the shape pattern of
  `Mob.Node.BLE.LocalInboxNativeSurface` so the same screen
  conventions (rows + meta strings + empty label) carry over.

  Identity (the local peer_id) is taken as an opt so the surface can
  flag the user's own messages without a process round-trip. When
  omitted, all messages are rendered with `from_self?: false`.
  """

  alias Mob.Node.Chat.ChannelViewModel.Message

  @type row :: %{
          message_id: binary(),
          body: binary(),
          sender_label: binary(),
          meta: binary(),
          direction: Message.direction(),
          status: Message.status(),
          from_self?: boolean()
        }

  @type t :: %{
          title: binary(),
          channel: binary(),
          empty?: boolean(),
          empty_label: binary(),
          message_count: non_neg_integer(),
          rows: [row()],
          placeholder: binary()
        }

  @doc """
  Builds the screen surface from a ChannelViewModel `snapshot`.

  Opts:
    * `:local_peer_id` — when present, rows whose envelope sender matches
      are tagged `from_self?: true` so the screen can right-align them.
    * `:nickname_for` — `(peer_id -> nickname)` fun for display labels;
      defaults to the raw peer_id.
    * `:now_ms` — clock seam for "Xs ago" labels (test reproducibility);
      defaults to `System.system_time(:millisecond)`.
  """
  @spec build(map(), keyword()) :: t()
  def build(snapshot, opts \\ []) do
    local_peer_id = Keyword.get(opts, :local_peer_id)
    nickname_for = Keyword.get(opts, :nickname_for, &Function.identity/1)
    now_ms = Keyword.get(opts, :now_ms, System.system_time(:millisecond))

    rows =
      snapshot.messages
      |> Enum.map(&to_row(&1, local_peer_id, nickname_for, now_ms))

    %{
      title: snapshot.channel,
      channel: snapshot.channel,
      empty?: rows == [],
      empty_label: empty_label(snapshot.channel),
      message_count: snapshot.message_count,
      rows: rows,
      placeholder: "Message #{snapshot.channel}"
    }
  end

  defp to_row(%Message{} = m, local_peer_id, nickname_for, now_ms) do
    %{
      message_id: m.message_id,
      body: m.body,
      sender_label: safe_nickname(nickname_for, m.sender_peer_id),
      meta: meta_string(m, now_ms),
      direction: m.direction,
      status: m.status,
      from_self?: m.sender_peer_id == local_peer_id
    }
  end

  defp safe_nickname(fun, peer_id) when is_function(fun, 1) do
    case fun.(peer_id) do
      nickname when is_binary(nickname) and byte_size(nickname) > 0 -> nickname
      _ -> peer_id
    end
  end

  defp meta_string(%Message{at: at, status: status, direction: direction}, now_ms) do
    age = age_label(now_ms - at)

    base =
      case direction do
        :out -> "you · #{age}"
        :in -> age
      end

    case status do
      :pending -> "#{base} · sending"
      :failed -> "#{base} · failed"
      :delivered -> base
    end
  end

  defp age_label(delta_ms) when delta_ms < 0, do: "just now"
  defp age_label(delta_ms) when delta_ms < 60_000, do: "#{div(delta_ms, 1000)}s ago"
  defp age_label(delta_ms) when delta_ms < 3_600_000, do: "#{div(delta_ms, 60_000)}m ago"
  defp age_label(delta_ms) when delta_ms < 86_400_000, do: "#{div(delta_ms, 3_600_000)}h ago"
  defp age_label(delta_ms), do: "#{div(delta_ms, 86_400_000)}d ago"

  defp empty_label(channel), do: "No messages in #{channel} yet. Say hi."
end
