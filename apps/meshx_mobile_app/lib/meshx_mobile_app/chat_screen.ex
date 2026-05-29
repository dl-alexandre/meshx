defmodule MeshxMobileApp.ChatScreen do
  @moduledoc """
  Per-channel chat surface.

  Owns a `MeshxMobileApp.Chat.ChannelViewModel` for the selected channel,
  subscribes to its push updates, and renders the
  `MeshxMobileApp.Chat.ChannelNativeSurface` into Mob components. The
  user types in a `<TextField>`, taps "Send", and the screen calls
  `ChannelViewModel.send_text/2`; the outbound entry is appended as
  `:pending` and rendered immediately.

  Channel selection comes from mount params (`"channel"`). When absent,
  defaults to `#general` so the screen is usable from a top-level entry
  point too.
  """

  use Mob.Screen

  alias MeshxMobileApp.Chat.{ChannelNativeSurface, ChannelViewModel, Identity}

  @impl Mob.Screen
  def mount(params, _session, socket) do
    channel = Map.get(params, "channel", "#general")
    {:ok, vm} = ChannelViewModel.start_link(channel: channel)
    {:ok, snapshot} = ChannelViewModel.subscribe(vm)

    # Identity.get/0's spec is `{:ok, t()}`; let the screen crash on init if
    # the store isn't up so the supervisor surfaces the real cause instead of
    # masking it as a "nil sender" UX bug. The wire_peer_id (raw 32 bytes) is
    # what envelopes carry, so `from_self?` row tagging matches consistently.
    {:ok, %{wire_peer_id: local_peer_id}} = Identity.get()

    socket =
      socket
      |> Mob.Socket.assign(:vm, vm)
      |> Mob.Socket.assign(:channel, channel)
      |> Mob.Socket.assign(:draft, "")
      |> Mob.Socket.assign(:status_line, nil)
      |> Mob.Socket.assign(:local_peer_id, local_peer_id)
      |> assign_snapshot(snapshot)

    {:ok, socket}
  end

  @impl Mob.Screen
  def render(assigns) do
    surface =
      ChannelNativeSurface.build(assigns.snapshot, local_peer_id: assigns.local_peer_id)

    ~MOB"""
    <Scroll background={:background}>
      <Column background={:background} padding={:space_lg} gap={:space_md}>
        <Text text={surface.title} text_size={:xl} text_color={:on_surface} />
        <Text text={message_count_line(surface)} text_size={:sm} text_color={:muted} />
        {messages(surface)}
        {compose_row(assigns, surface)}
        {status_line(assigns.status_line)}
      </Column>
    </Scroll>
    """
  end

  @impl Mob.Screen
  def handle_info({:change, :draft, new_text}, socket) do
    {:noreply, Mob.Socket.assign(socket, :draft, new_text)}
  end

  def handle_info({:tap, :send}, socket) do
    draft = String.trim(socket.assigns.draft || "")

    case draft do
      "" ->
        {:noreply, Mob.Socket.assign(socket, :status_line, "Empty message ignored")}

      text ->
        case ChannelViewModel.send_text(socket.assigns.vm, text) do
          {:ok, _msg_id} ->
            socket =
              socket
              |> Mob.Socket.assign(:draft, "")
              |> Mob.Socket.assign(:status_line, nil)

            {:noreply, socket}

          {:error, reason} ->
            {:noreply, Mob.Socket.assign(socket, :status_line, "Send failed: #{inspect(reason)}")}
        end
    end
  end

  def handle_info({ChannelViewModel, :updated, snapshot}, socket) do
    {:noreply, assign_snapshot(socket, snapshot)}
  end

  def handle_info(_other, socket), do: {:noreply, socket}

  # ── render helpers ──────────────────────────────────────────────────────

  defp assign_snapshot(socket, snapshot) do
    Mob.Socket.assign(socket, :snapshot, snapshot)
  end

  defp message_count_line(surface) do
    case surface.message_count do
      0 -> "—"
      n -> "#{n} message#{if n == 1, do: "", else: "s"}"
    end
  end

  defp messages(%{empty?: true} = surface) do
    ~MOB(<Text text={surface.empty_label} text_size={:sm} text_color={:muted} />)
  end

  defp messages(surface) do
    ~MOB"""
    <Column background={:background} gap={:space_sm}>
      {Enum.map(surface.rows, &message_row/1)}
    </Column>
    """
  end

  defp message_row(row) do
    body_text = row_body(row)
    background = if row.from_self?, do: :primary, else: :surface
    text_color = if row.from_self?, do: :on_primary, else: :on_surface

    ~MOB"""
    <Column background={background} padding={:space_sm} gap={:space_sm}>
      <Text text={row.sender_label} text_size={:sm} text_color={text_color} />
      <Text text={body_text} text_size={:md} text_color={text_color} />
      <Text text={row.meta} text_size={:sm} text_color={:muted} />
    </Column>
    """
  end

  defp row_body(row), do: row.body

  defp compose_row(assigns, surface) do
    on_change = {self(), :draft}
    send_tap = {self(), :send}

    ~MOB"""
    <Row fill_width={true} gap={:space_sm}>
      <TextField
        value={assigns.draft}
        placeholder={surface.placeholder}
        on_change={on_change}
        return_key="send"
        fill_width={true}
      />
      <Button
        text="Send"
        background={:primary}
        text_color={:on_primary}
        padding={:space_md}
        on_tap={send_tap}
      />
    </Row>
    """
  end

  defp status_line(nil), do: ~MOB(<Text text="" text_size={:sm} text_color={:muted} />)

  defp status_line(line) do
    ~MOB(<Text text={line} text_size={:sm} text_color={:muted} />)
  end
end
