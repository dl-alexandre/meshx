defmodule Mob.Node.Chat.ChannelNativeSurfaceEncryptionTest do
  use ExUnit.Case, async: true

  alias Mob.Node.Chat.ChannelNativeSurface
  alias Mob.Node.Chat.ChannelViewModel.Message

  defp msg(attrs) do
    struct!(
      %Message{
        message_id: "id",
        sender_peer_id: "bob",
        body: "",
        at: 0,
        direction: :in,
        status: :delivered
      },
      attrs
    )
  end

  defp snapshot(messages),
    do: %{channel: "#general", messages: messages, message_count: length(messages)}

  test "encrypted? opt prefixes the title with a lock" do
    surface = ChannelNativeSurface.build(snapshot([]), encrypted?: true, now_ms: 0)
    assert surface.encrypted?
    assert surface.title == "🔒 #general"
    assert surface.channel == "#general"
  end

  test "a cleartext channel keeps a plain title" do
    surface = ChannelNativeSurface.build(snapshot([]), now_ms: 0)
    refute surface.encrypted?
    assert surface.title == "#general"
  end

  test "a locked message renders a placeholder body and marks the channel encrypted" do
    surface =
      ChannelNativeSurface.build(snapshot([msg(body: "", locked: true)]), now_ms: 0)

    assert [row] = surface.rows
    assert row.locked?
    assert row.body == "🔒 Encrypted message — waiting for key"
    # title badge can't be out of sync with a locked message present
    assert surface.encrypted?
    assert surface.title == "🔒 #general"
  end

  test "an unlocked decrypted message shows its plaintext body" do
    surface =
      ChannelNativeSurface.build(snapshot([msg(body: "hello", locked: false)]),
        encrypted?: true,
        now_ms: 0
      )

    assert [%{body: "hello", locked?: false}] = surface.rows
  end
end
