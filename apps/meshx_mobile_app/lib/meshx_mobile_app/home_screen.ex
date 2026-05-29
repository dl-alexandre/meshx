defmodule MeshxMobileApp.HomeScreen do
  @moduledoc "MeshX mobile control surface rendered by Mob."

  use Mob.Screen

  alias MeshxMobileApp.BLE.LocalInboxNativeSurface
  alias MeshxMobileApp.Session

  @impl Mob.Screen
  def mount(_params, _session, socket) do
    {:ok, session} = Session.start_link()
    :ok = Session.subscribe(session, self())

    socket =
      socket
      |> Mob.Socket.assign(:session, session)
      |> Mob.Socket.assign(:local_inbox_state_filter, :all)
      |> Mob.Socket.assign(:local_inbox_sort, :state_then_recent)
      |> Mob.Socket.assign(:local_inbox_detail_message_key, nil)
      |> assign_snapshot(Session.snapshot(session))

    {:ok, socket}
  end

  @impl Mob.Screen
  def render(assigns) do
    ~MOB"""
    <Scroll background={:background}>
      <Column background={:background} padding={:space_lg} gap={:space_md}>
        <Text text="MeshX" text_size={:xl} text_color={:on_surface} />
        <Text text="Mob runtime" text_size={:sm} text_color={:primary} />
        <Row fill_width={true} gap={:space_sm}>
          {mode_button("Scan", :scan, assigns.mode)}
          {mode_button("Advertise", :advertise, assigns.mode)}
        </Row>
        <Text text={"Status: #{assigns.status}"} text_size={:md} text_color={:on_surface} />
        <Text text={"Peer: #{assigns.peer_id || "None"}"} text_size={:sm} text_color={:muted} />
        <Row fill_width={true} gap={:space_sm}>
          {action_button(start_label(assigns.mode), :start)}
          {action_button("Stop", :stop)}
        </Row>
        {action_button("Ping Secure Peer", :ping)}
        {action_button("Chat", :open_chat)}
        {local_inbox_surface(assigns)}
        <Text text="Events" text_size={:md} text_color={:on_surface} />
        <Text text={events_text(assigns.events)} text_size={:sm} text_color={:muted} />
      </Column>
    </Scroll>
    """
  end

  @impl Mob.Screen
  def handle_info({:tap, :mode_scan}, socket) do
    {:noreply, update_from_session(socket, &Session.set_mode(&1, :scan))}
  end

  def handle_info({:tap, :mode_advertise}, socket) do
    {:noreply, update_from_session(socket, &Session.set_mode(&1, :advertise))}
  end

  def handle_info({:tap, :start}, socket) do
    {:noreply, update_from_session(socket, &Session.start/1)}
  end

  def handle_info({:tap, :stop}, socket) do
    {:noreply, update_from_session(socket, &Session.stop/1)}
  end

  def handle_info({:tap, :ping}, socket) do
    {:noreply, update_from_session(socket, &Session.send_ping/1)}
  end

  def handle_info({:tap, :open_chat}, socket) do
    # TODO: nav push API in this Mob version is unverified — deps/mob source
    # was iCloud-dematerialized when the chat MVP landed. Wire to whatever
    # `Mob.Screen.push` / `Mob.Nav.push` / `Mob.Socket.*` call the framework
    # exposes once deps/mob is readable.
    {:noreply, socket}
  end

  def handle_info({:tap, {:local_inbox_filter, state}}, socket) do
    socket =
      socket
      |> Mob.Socket.assign(:local_inbox_state_filter, state)
      |> Mob.Socket.assign(:local_inbox_detail_message_key, nil)

    {:noreply, socket}
  end

  def handle_info({:tap, {:local_inbox_sort, sort}}, socket) do
    {:noreply, Mob.Socket.assign(socket, :local_inbox_sort, sort)}
  end

  def handle_info({:tap, {:local_inbox_detail, message_key}}, socket) do
    {:noreply, Mob.Socket.assign(socket, :local_inbox_detail_message_key, message_key)}
  end

  def handle_info({Session, :updated, snapshot}, socket) do
    {:noreply, assign_snapshot(socket, snapshot)}
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  defp update_from_session(socket, fun) do
    socket.assigns.session
    |> fun.()
    |> then(&assign_snapshot(socket, &1))
  end

  defp assign_snapshot(socket, snapshot) do
    Enum.reduce(snapshot, socket, fn {key, value}, socket ->
      Mob.Socket.assign(socket, key, value)
    end)
  end

  defp mode_button(label, mode, active_mode) do
    tap = {self(), :"mode_#{mode}"}
    background = if mode == active_mode, do: :primary, else: :surface
    text_color = if mode == active_mode, do: :on_primary, else: :on_surface

    ~MOB(<Button
  text={label}
  background={background}
  text_color={text_color}
  padding={:space_sm}
  weight={1}
  on_tap={tap}
/>)
  end

  defp action_button(label, tag) do
    tap = {self(), tag}

    ~MOB(<Button
  text={label}
  background={:primary}
  text_color={:on_primary}
  padding={:space_md}
  fill_width={true}
  on_tap={tap}
/>)
  end

  defp start_label(:advertise), do: "Advertise"
  defp start_label(_mode), do: "Scan"

  defp local_inbox_surface(assigns) do
    surface =
      LocalInboxNativeSurface.build(assigns.local_inbox,
        selected_state: assigns.local_inbox_state_filter,
        sort: assigns.local_inbox_sort,
        detail_message_key: assigns.local_inbox_detail_message_key
      )

    ~MOB"""
    <Column background={:background} gap={:space_sm}>
      <Text text={surface.title} text_size={:md} text_color={:on_surface} />
      <Text text={surface.summary_line} text_size={:sm} text_color={:muted} />
      <Text text={surface.filter_summary} text_size={:sm} text_color={:muted} />
      <Text text={surface.sort_summary} text_size={:sm} text_color={:muted} />
      <Row fill_width={true} gap={:space_sm}>
        {Enum.map(surface.state_filters, &state_filter_button/1)}
      </Row>
      <Row fill_width={true} gap={:space_sm}>
        {Enum.map(surface.sort_options, &sort_button/1)}
      </Row>
      {local_inbox_sections(surface)}
      {local_inbox_detail(surface.detail)}
      {local_inbox_warnings(surface.warnings)}
    </Column>
    """
  end

  defp state_filter_button(filter) do
    tap = {self(), {:local_inbox_filter, filter.state}}
    background = if filter.selected?, do: :primary, else: :surface
    text_color = if filter.selected?, do: :on_primary, else: :on_surface
    text = "#{Map.get(filter, :short_label, filter.label)} #{filter.count}"

    ~MOB(<Button
  text={text}
  background={background}
  text_color={text_color}
  padding={:space_sm}
  weight={1}
  on_tap={tap}
/>)
  end

  defp sort_button(option) do
    tap = {self(), {:local_inbox_sort, option.sort}}
    background = if option.selected?, do: :primary, else: :surface
    text_color = if option.selected?, do: :on_primary, else: :on_surface

    ~MOB(<Button
  text={option.label}
  background={background}
  text_color={text_color}
  padding={:space_sm}
  weight={1}
  on_tap={tap}
/>)
  end

  defp local_inbox_sections(%{empty?: true} = surface) do
    ~MOB(<Text text={surface.empty_label} text_size={:sm} text_color={:muted} />)
  end

  defp local_inbox_sections(surface) do
    ~MOB"""
    <Column background={:background} gap={:space_sm}>
      {Enum.map(surface.sections, &local_inbox_section/1)}
    </Column>
    """
  end

  defp local_inbox_section(%{count: 0} = section) do
    ~MOB"""
    <Column background={:background} gap={:space_sm}>
      <Text text={section_header(section)} text_size={:sm} text_color={:on_surface} />
      <Text text={section.empty_label} text_size={:sm} text_color={:muted} />
    </Column>
    """
  end

  defp local_inbox_section(section) do
    ~MOB"""
    <Column background={:background} gap={:space_sm}>
      <Text text={section_header(section)} text_size={:sm} text_color={:on_surface} />
      {Enum.map(section.rows, &local_inbox_row/1)}
    </Column>
    """
  end

  defp section_header(section), do: "#{section.label} #{section.count}"

  defp local_inbox_row(row) do
    tap = {self(), {:local_inbox_detail, row.message_key}}
    background = if row.selected?, do: :primary, else: :surface
    text_color = if row.selected?, do: :on_primary, else: :on_surface

    ~MOB"""
    <Button
      text={row_text(row)}
      background={background}
      text_color={text_color}
      padding={:space_md}
      fill_width={true}
      on_tap={tap}
    />
    """
  end

  defp row_text(row) do
    [
      "#{row.badge}  #{row.title}",
      row.subtitle,
      row.meta
    ]
    |> Enum.join("\n")
  end

  defp local_inbox_detail(nil) do
    ~MOB(<Text text="Select a nearby message for details" text_size={:sm} text_color={:muted} />)
  end

  defp local_inbox_detail(%{status: :not_found} = detail) do
    ~MOB(<Text text={detail.title} text_size={:sm} text_color={:muted} />)
  end

  defp local_inbox_detail(%{status: :selected} = detail) do
    ~MOB"""
    <Column background={:background} gap={:space_sm}>
      <Text text="Details" text_size={:md} text_color={:on_surface} />
      <Text text={detail_text(detail)} text_size={:sm} text_color={:muted} />
    </Column>
    """
  end

  defp detail_text(detail) do
    detail.detail_lines
    |> Enum.join("\n")
  end

  defp local_inbox_warnings([]), do: ~MOB(<Text text="" text_size={:sm} text_color={:muted} />)

  defp local_inbox_warnings(warnings) do
    text = Enum.join(warnings, "\n")

    ~MOB(<Text text={text} text_size={:sm} text_color={:muted} />)
  end

  defp events_text([]), do: "No events"

  defp events_text(events) do
    events
    |> Enum.take(8)
    |> Enum.map_join("\n", fn event ->
      "#{DateTime.to_time(event.at)}  #{event.title}: #{event.detail}"
    end)
  end
end
