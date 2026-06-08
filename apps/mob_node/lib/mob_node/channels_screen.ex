defmodule Mob.Node.ChannelsScreen do
  @moduledoc """
  Channel list — entry point into the chat stack.

  Tracks the set of channels the user has joined (default: `#general`),
  shows a per-channel row, lets the user join a new channel via a
  `<TextField>`, and pushes `ChatScreen` for the tapped channel.

  Channels persist via `Mob.Store.DB` under `{:chat, :joined_channels}`
  so the list survives app restarts. The MVP keeps a single MapSet; an
  unread-count column will follow once the per-channel ViewModel is
  supervised (so this screen can `snapshot/1` each without owning them).
  """

  use Mob.Screen

  alias Mob.Node.MeshStatus
  alias Mob.Store.DB

  @joined_key {:chat, :joined_channels}
  @default_channel "#general"

  @impl Mob.Screen
  def mount(_params, _session, socket) do
    channels = load_channels()

    socket =
      socket
      |> Mob.Socket.assign(:channels, channels)
      |> Mob.Socket.assign(:draft, "")
      |> Mob.Socket.assign(:status_line, nil)

    {:ok, socket}
  end

  @impl Mob.Screen
  def render(assigns) do
    readiness = MeshStatus.readiness()

    ~MOB"""
    <Scroll background={:background}>
      <Column background={:background} padding={:space_lg} gap={:space_md}>
        <Text text="Channels" text_size={:xl} text_color={:on_surface} />
        {readiness_banner(readiness)}
        <Text text={summary_line(assigns.channels)} text_size={:sm} text_color={:muted} />
        {channel_list(assigns.channels)}
        {join_row(assigns)}
        {status_line(assigns.status_line)}
      </Column>
    </Scroll>
    """
  end

  @impl Mob.Screen
  def handle_info({:change, :join_draft, new_text}, socket) do
    {:noreply, Mob.Socket.assign(socket, :draft, new_text)}
  end

  def handle_info({:tap, :join}, socket) do
    case normalize_channel(socket.assigns.draft) do
      {:ok, channel} ->
        channels = MapSet.put(socket.assigns.channels, channel)
        :ok = save_channels(channels)

        socket =
          socket
          |> Mob.Socket.assign(:channels, channels)
          |> Mob.Socket.assign(:draft, "")
          |> Mob.Socket.assign(:status_line, "Joined #{channel}")

        {:noreply, socket}

      {:error, reason} ->
        {:noreply, Mob.Socket.assign(socket, :status_line, reason)}
    end
  end

  def handle_info({:tap, {:open, channel}}, socket) do
    {:noreply, Mob.Socket.push_screen(socket, Mob.Node.ChatScreen, %{"channel" => channel})}
  end

  def handle_info(_other, socket), do: {:noreply, socket}

  # ── pure helpers (testable without a process) ───────────────────────────

  @doc false
  @spec normalize_channel(String.t() | nil) :: {:ok, String.t()} | {:error, String.t()}
  def normalize_channel(nil), do: {:error, "Channel name is required"}

  def normalize_channel(input) when is_binary(input) do
    trimmed = String.trim(input)

    cond do
      trimmed == "" ->
        {:error, "Channel name is required"}

      String.contains?(trimmed, " ") ->
        {:error, "Channel name cannot contain spaces"}

      true ->
        {:ok, ensure_hash(trimmed)}
    end
  end

  defp ensure_hash("#" <> _ = name), do: name
  defp ensure_hash(name), do: "#" <> name

  defp summary_line(channels) do
    case MapSet.size(channels) do
      1 -> "1 channel"
      n -> "#{n} channels"
    end
  end

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

  defp channel_list(channels) do
    rows =
      channels
      |> Enum.sort()
      |> Enum.map(&channel_row/1)

    ~MOB"""
    <Column background={:background} gap={:space_sm}>
      {rows}
    </Column>
    """
  end

  defp channel_row(channel) do
    tap = {self(), {:open, channel}}

    ~MOB"""
    <Button
      text={channel}
      background={:surface}
      text_color={:on_surface}
      padding={:space_md}
      fill_width={true}
      on_tap={tap}
    />
    """
  end

  defp join_row(assigns) do
    on_change = {self(), :join_draft}
    join_tap = {self(), :join}

    ~MOB"""
    <Row fill_width={true} gap={:space_sm}>
      <TextField
        value={assigns.draft}
        placeholder="Join channel (e.g. #random)"
        on_change={on_change}
        return_key="go"
        fill_width={true}
      />
      <Button
        text="Join"
        background={:primary}
        text_color={:on_primary}
        padding={:space_md}
        on_tap={join_tap}
      />
    </Row>
    """
  end

  defp status_line(nil), do: ~MOB(<Text text="" text_size={:sm} text_color={:muted} />)

  defp status_line(line) do
    ~MOB(<Text text={line} text_size={:sm} text_color={:muted} />)
  end

  # ── persistence ─────────────────────────────────────────────────────────

  defp load_channels do
    case DB.get(@joined_key) do
      nil -> MapSet.new([@default_channel])
      list when is_list(list) -> MapSet.new(list)
      %MapSet{} = set -> set
    end
  end

  defp save_channels(channels) do
    DB.put(@joined_key, MapSet.to_list(channels))
    :ok
  end
end
