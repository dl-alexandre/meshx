defmodule MeshxMobileApp.Chat.ChannelNativeSurfaceTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.Chat.ChannelNativeSurface
  alias MeshxMobileApp.Chat.ChannelViewModel.Message

  defp snapshot(messages, channel \\ "#general") do
    %{channel: channel, messages: messages, message_count: length(messages)}
  end

  defp msg(opts) do
    %Message{
      message_id: opts[:message_id] || <<0::128>>,
      sender_peer_id: opts[:sender_peer_id] || "bob",
      body: opts[:body] || "hi",
      at: opts[:at] || 0,
      direction: opts[:direction] || :in,
      status: opts[:status] || :delivered
    }
  end

  describe "build/2 — empty channel" do
    test "empty?, count 0, channel-aware empty_label and placeholder" do
      surface = ChannelNativeSurface.build(snapshot([]))
      assert surface.channel == "#general"
      assert surface.title == "#general"
      assert surface.empty? == true
      assert surface.message_count == 0
      assert surface.rows == []
      assert surface.placeholder == "Message #general"
      assert surface.empty_label =~ "#general"
    end
  end

  describe "build/2 — rendering rows" do
    test "tags `from_self?` when sender matches local_peer_id" do
      msgs = [msg(sender_peer_id: "alice"), msg(sender_peer_id: "bob")]
      surface = ChannelNativeSurface.build(snapshot(msgs), local_peer_id: "alice")
      assert [a, b] = surface.rows
      assert a.from_self? == true
      assert b.from_self? == false
    end

    test "preserves order and counts" do
      msgs = [msg(body: "1"), msg(body: "2"), msg(body: "3")]
      surface = ChannelNativeSurface.build(snapshot(msgs))
      assert Enum.map(surface.rows, & &1.body) == ["1", "2", "3"]
      assert surface.message_count == 3
      assert surface.empty? == false
    end

    test "uses nickname_for/1 when it returns a non-empty string" do
      msgs = [msg(sender_peer_id: "abc123")]

      surface =
        ChannelNativeSurface.build(snapshot(msgs),
          nickname_for: fn "abc123" -> "Alice" end
        )

      assert [%{sender_label: "Alice"}] = surface.rows
    end

    test "falls back to raw peer_id when nickname_for returns invalid value" do
      msgs = [msg(sender_peer_id: "abc123")]

      for bad <- [nil, "", :not_binary] do
        surface =
          ChannelNativeSurface.build(snapshot(msgs),
            nickname_for: fn _ -> bad end
          )

        assert [%{sender_label: "abc123"}] = surface.rows
      end
    end
  end

  describe "build/2 — meta strings" do
    test "outbound rows prefix with 'you ·' and use age_label" do
      m = msg(direction: :out, at: 0, status: :delivered)
      surface = ChannelNativeSurface.build(snapshot([m]), now_ms: 5_000)
      assert [%{meta: "you · 5s ago"}] = surface.rows
    end

    test "outbound :pending appends 'sending'" do
      m = msg(direction: :out, at: 0, status: :pending)
      surface = ChannelNativeSurface.build(snapshot([m]), now_ms: 2_000)
      assert [%{meta: "you · 2s ago · sending"}] = surface.rows
    end

    test "outbound :failed appends 'failed'" do
      m = msg(direction: :out, at: 0, status: :failed)
      surface = ChannelNativeSurface.build(snapshot([m]), now_ms: 1_000)
      assert [%{meta: "you · 1s ago · failed"}] = surface.rows
    end

    test "inbound rows are just the age (no 'you ·' prefix)" do
      m = msg(direction: :in, at: 0, status: :delivered)
      surface = ChannelNativeSurface.build(snapshot([m]), now_ms: 90_000)
      assert [%{meta: "1m ago"}] = surface.rows
    end

    test "age_label handles seconds / minutes / hours / days / future" do
      # {delta_ms, expected_meta_string}
      cases = [
        {-1, "just now"},
        {500, "0s ago"},
        {30_000, "30s ago"},
        {59_999, "59s ago"},
        {60_000, "1m ago"},
        {3_599_999, "59m ago"},
        {3_600_000, "1h ago"},
        {86_399_999, "23h ago"},
        {86_400_000, "1d ago"},
        {2 * 86_400_000, "2d ago"}
      ]

      for {delta, expected} <- cases do
        m = msg(direction: :in, at: 0, status: :delivered)
        surface = ChannelNativeSurface.build(snapshot([m]), now_ms: delta)
        assert [%{meta: ^expected}] = surface.rows, "delta=#{delta}"
      end
    end
  end
end
