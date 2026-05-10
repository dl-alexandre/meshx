defmodule MeshxMob.PlatformStateTest do
  use ExUnit.Case, async: false

  alias MeshxMob.{Platform, PlatformState}

  setup do
    # Start an isolated, named-by-pid PlatformState for each test.
    {:ok, pid} = PlatformState.start_link(name: nil, platform: %{os: :ios})
    {:ok, server: pid}
  end

  test "initial state reflects the supplied platform", %{server: s} do
    assert %Platform{os: :ios, background_mode: :foreground} = PlatformState.get(s)
  end

  test "initial state defaults to an unknown platform" do
    {:ok, pid} = PlatformState.start_link(name: nil)

    assert %Platform{os: :unknown, background_mode: :foreground} = PlatformState.get(pid)
  end

  test "registered server uses convenience APIs" do
    {:ok, pid} = PlatformState.start_link(platform: %{os: :android})

    on_exit(fn ->
      if Process.alive?(pid), do: GenServer.stop(pid)
    end)

    assert %Platform{os: :android, background_mode: :foreground} = PlatformState.get()

    :ok = PlatformState.subscribe()
    assert {:ok, :background} = PlatformState.transition(:background)
    assert_receive {:meshx_mob, :background_mode, %{from: :foreground, to: :background}}

    :ok = PlatformState.unsubscribe()
    assert {:ok, :foreground} = PlatformState.transition(:foreground)
    refute_receive {:meshx_mob, :background_mode, _}, 50
  end

  test "subscribers receive transition events", %{server: s} do
    :ok = PlatformState.subscribe(s, self())

    assert {:ok, :background} = PlatformState.transition(s, :background)
    assert_receive {:meshx_mob, :background_mode, %{from: :foreground, to: :background}}

    assert {:ok, :suspended} = PlatformState.transition(s, :suspended)
    assert_receive {:meshx_mob, :background_mode, %{from: :background, to: :suspended}}

    assert {:ok, :foreground} = PlatformState.transition(s, :foreground)
    assert_receive {:meshx_mob, :background_mode, %{from: :suspended, to: :foreground}}
  end

  test "no event is emitted for a no-op transition", %{server: s} do
    :ok = PlatformState.subscribe(s, self())

    # Already in :foreground.
    assert {:ok, :foreground} = PlatformState.transition(s, :foreground)
    refute_receive {:meshx_mob, :background_mode, _}, 50
  end

  test "invalid modes are rejected with a tagged error", %{server: s} do
    assert {:error, {:invalid_background_mode, :on_fire}} =
             PlatformState.transition(s, :on_fire)

    # Internal state was not corrupted.
    assert PlatformState.get(s).background_mode == :foreground
  end

  test "unknown messages are ignored", %{server: s} do
    send(s, :ignored)

    assert_eventually(fn -> PlatformState.get(s).background_mode == :foreground end)
  end

  test "unsubscribed callers stop receiving events", %{server: s} do
    :ok = PlatformState.subscribe(s, self())
    :ok = PlatformState.unsubscribe(s, self())

    assert {:ok, :background} = PlatformState.transition(s, :background)
    refute_receive {:meshx_mob, :background_mode, _}, 50
  end

  test "subscribers are auto-removed when their process dies", %{server: s} do
    parent = self()

    sub =
      spawn(fn ->
        :ok = PlatformState.subscribe(s, self())
        send(parent, :subscribed)

        receive do
          :stop -> :ok
        end
      end)

    assert_receive :subscribed
    Process.exit(sub, :kill)
    # Give the DOWN message time to land.
    Process.sleep(20)

    # Should NOT raise even though the dead process is the only "subscriber".
    assert {:ok, :background} = PlatformState.transition(s, :background)
  end

  test "transitions feed correctly into Platform.to_metadata for transport advertisement",
       %{server: s} do
    {:ok, :background} = PlatformState.transition(s, :background)

    metadata = s |> PlatformState.get() |> Platform.to_metadata()
    assert metadata.mobile.background_mode == :background
    assert metadata.mobile.os == :ios
  end

  defp assert_eventually(fun, attempts \\ 20)

  defp assert_eventually(fun, attempts) when attempts > 0 do
    if fun.() do
      assert true
    else
      Process.sleep(10)
      assert_eventually(fun, attempts - 1)
    end
  end

  defp assert_eventually(fun, 0), do: assert(fun.())
end
