defmodule Mob.Node.HomeScreenTest do
  use ExUnit.Case, async: false

  alias Mob.Node.HomeScreen

  setup do
    Application.ensure_all_started(:mob_store)
    ensure_db_started()
    :ok
  end

  defp mounted_socket do
    socket = Mob.Socket.new(HomeScreen)
    assert {:ok, socket} = HomeScreen.mount(%{}, %{}, socket)

    on_exit(fn ->
      if Process.alive?(socket.assigns.session) do
        GenServer.stop(socket.assigns.session)
      end
    end)

    socket
  end

  defp ensure_db_started do
    case Mob.Store.DB.start_link([]) do
      {:ok, pid} ->
        Process.unlink(pid)
        :ok

      {:error, {:already_started, _pid}} ->
        :ok
    end
  end

  test "mount initializes nearby messages control state" do
    socket = mounted_socket()

    assert socket.assigns.local_inbox_state_filter == :all
    assert socket.assigns.local_inbox_sort == :state_then_recent
    assert socket.assigns.local_inbox_detail_message_key == nil
    assert socket.assigns.local_inbox.nearby_messages == []
    assert socket.assigns.status == "Waiting for Bluetooth"
  end

  test "nearby messages controls update local view state without transport work" do
    socket =
      mounted_socket()
      |> Mob.Socket.assign(:local_inbox_detail_message_key, "selected-ref")

    assert {:noreply, socket} =
             HomeScreen.handle_info({:tap, {:local_inbox_filter, :gossiped_ref}}, socket)

    assert socket.assigns.local_inbox_state_filter == :gossiped_ref
    assert socket.assigns.local_inbox_detail_message_key == nil

    assert {:noreply, socket} =
             HomeScreen.handle_info({:tap, {:local_inbox_sort, :strongest_rssi}}, socket)

    assert socket.assigns.local_inbox_sort == :strongest_rssi

    assert {:noreply, socket} =
             HomeScreen.handle_info({:tap, {:local_inbox_detail, "message-key"}}, socket)

    assert socket.assigns.local_inbox_detail_message_key == "message-key"
  end
end
