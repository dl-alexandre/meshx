defmodule Mob.Node.ChatScreen do
  @moduledoc """
  Per-channel chat surface.

  Owns a `Mob.Node.Chat.ChannelViewModel` for the selected channel,
  subscribes to its push updates, and renders the
  `Mob.Node.Chat.ChannelNativeSurface` into Mob components. The
  user types in a `<TextField>`, taps "Send", and the screen calls
  `ChannelViewModel.send_text/2`; the outbound entry is appended as
  `:pending` and rendered immediately.

  Channel selection comes from mount params (`"channel"`). When absent,
  defaults to `#general` so the screen is usable from a top-level entry
  point too.
  """

  use Mob.Screen

  alias Mob.Node.Chat.{ChannelNativeSurface, ChannelViewModel, Identity}
  alias Mob.Node.MeshStatus

  @impl Mob.Screen
  def mount(params, _session, socket) do
    channel = Map.get(params, "channel", "#general")
    {:ok, vm} = ChannelViewModel.start_link(channel: channel)
    {:ok, snapshot} = ChannelViewModel.subscribe(vm)
    {:ok, identity} = Identity.get()

    socket =
      socket
      |> Mob.Socket.assign(:vm, vm)
      |> Mob.Socket.assign(:channel, channel)
      |> Mob.Socket.assign(:draft, "")
      |> Mob.Socket.assign(:status_line, nil)
      |> Mob.Socket.assign(:local_peer_id, identity.wire_peer_id)
      |> Mob.Socket.assign(:nickname_for, nickname_for_fn(identity))
      |> assign_snapshot(snapshot)

    {:ok, socket}
  end

  @impl Mob.Screen
  def render(assigns) do
    readiness = MeshStatus.readiness()

    surface =
      ChannelNativeSurface.build(assigns.snapshot,
        local_peer_id: assigns.local_peer_id,
        nickname_for: assigns.nickname_for
      )

    ~MOB"""
    <Scroll background={:background}>
      <Column background={:background} padding={:space_lg} gap={:space_md}>
        <Text text={surface.title} text_size={:xl} text_color={:on_surface} />
        {readiness_banner(readiness)}
        <Text text={message_count_line(surface)} text_size={:sm} text_color={:muted} />
        {messages(surface)}
        {compose_row(assigns, surface, readiness)}
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
    readiness = MeshStatus.readiness()

    if MeshStatus.ready_for_chat?(readiness) do
      send_draft(socket)
    else
      {:noreply, Mob.Socket.assign(socket, :status_line, readiness.detail)}
    end
  end

  def handle_info({ChannelViewModel, :updated, snapshot}, socket) do
    {:noreply, assign_snapshot(socket, snapshot)}
  end

  def handle_info(_other, socket), do: {:noreply, socket}

  defp send_draft(socket) do
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
            msg = send_error_message(reason)
            {:noreply, Mob.Socket.assign(socket, :status_line, msg)}
        end
    end
  end

  defp nickname_for_fn(%{wire_peer_id: local_wire, nickname: local_nick}) do
    fn peer_id ->
      if peer_id == local_wire do
        local_nick
      else
        Identity.default_nickname(display_peer_id(peer_id))
      end
    end
  end

  defp display_peer_id(wire) when is_binary(wire) and byte_size(wire) > 0 do
    Base.url_encode64(wire, padding: false)
  end

  defp display_peer_id(_), do: "unknown"

  # ── render helpers ──────────────────────────────────────────────────────

  defp readiness_banner(%{state: state, headline: headline, detail: detail}) do
    {background, headline_color, detail_color} = Mob.Node.MeshStatusBanner.colors_for(state)
    tech = MeshStatus.line()

    ~MOB"""
    <Column background={background} padding={:space_md} gap={:space_sm}>
      <Text text={headline} text_size={:md} text_color={headline_color} />
      <Text text={detail} text_size={:sm} text_color={detail_color} />
      <Text text={tech} text_size={:sm} text_color={:muted} />
    </Column>
    """
  end

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

  defp compose_row(assigns, surface, readiness) do
    on_change = {self(), :draft}
    send_tap = {self(), :send}
    enabled = MeshStatus.ready_for_chat?(readiness)
    send_bg = if enabled, do: :primary, else: :surface
    send_fg = if enabled, do: :on_primary, else: :muted

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
        background={send_bg}
        text_color={send_fg}
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

  defp send_error_message({:broadcast_failed, :no_transports}),
    do: "Send failed: mesh transport not started. Restart the app."

  defp send_error_message({:broadcast_failed, _reason}),
    do: "Send failed: mesh transport unavailable. On Home, tap Start Scan or Advertise."

  defp send_error_message(:router_unavailable),
    do: "Send failed: mesh router not running."

  defp send_error_message(reason), do: "Send failed: #{inspect(reason)}"
end
