defmodule Mix.Tasks.Mob.Node.TwoDeviceMesh do
  @shortdoc "Automate two-device MobNode mesh chat bring-up (advertise + scan + #general)"

  @moduledoc """
  Restarts MobNode on two physical iOS devices, connects via distribution,
  drives Home/Chat UI with `Mob.Test`, and sends a test message on each.

  Defaults: Coding iPad advertises, DairyPhoneDeaux scans.

      mix mob.node.two_device_mesh
      mix mob.node.two_device_mesh --advertise 00008110-0006619A2132801E --scan 00008030-000209510ED0C02E
  """

  use Mix.Task

  alias MobDev.{Connector, Device, Tunnel}

  @switches [
    advertise: :string,
    scan: :string,
    boot_ms: :integer
  ]

  @impl Mix.Task
  def run(args) do
    {opts, _, invalid} = OptionParser.parse(args, switches: @switches)

    if invalid != [] do
      Mix.raise("Invalid options: #{inspect(invalid)}")
    end

    advertise_udid = opts[:advertise] || "00008030-000209510ED0C02E"
    scan_udid = opts[:scan] || "00008110-0006619A2132801E"
    boot_ms = opts[:boot_ms] || 18_000
    bundle = MobDev.Config.bundle_id()
    cookie = :mob_secret
    bundle_id = bundle

    advertise = device_for_udid(advertise_udid, "Advertise")
    scan = device_for_udid(scan_udid, "Scan")

    advertise = %{advertise | host_ip: advertise.host_ip || host_ip_for_udid(advertise_udid)}
    scan = %{scan | host_ip: scan.host_ip || host_ip_for_udid(scan_udid)}

    unless advertise.host_ip && scan.host_ip do
      Mix.raise("""
      Could not resolve device IPs (ARP / devicectl / mDNS). Plug both devices in via USB and retry.
      Run: arp -a | grep 169.254
      """)
    end

    IO.puts("\n=== Two-device mesh bring-up ===")
    IO.puts("  Advertise: #{advertise.name} #{advertise.serial} @ #{advertise.host_ip}")
    IO.puts("  Scan:      #{scan.name} #{scan.serial} @ #{scan.host_ip}")

    IO.puts("  Launching apps (unlock both devices if prompted)...")

    {advertise, advertise_launch} = launch_device(advertise, bundle)
    {scan, scan_launch} = launch_device(scan, bundle)

    case {launch_ok?(advertise_launch), launch_ok?(scan_launch)} do
      {true, true} ->
        :ok

      {true, false} ->
        IO.puts("""
        WARNING: #{scan.name} did not launch (likely locked). Continuing with #{advertise.name} only.
        Unlock the phone and tap through Home → Scan → Start Scanning manually.
        """)

      {false, true} ->
        Mix.raise("""
        Could not launch #{advertise.name}. Unlock it and rerun:
          mix mob.node.two_device_mesh
        """)

      {false, false} ->
        Mix.raise("""
        Could not launch either device. Unlock both and rerun:
          mix mob.node.two_device_mesh
        """)
    end

    IO.puts("  Waiting #{boot_ms}ms for BEAM boot...")
    Process.sleep(boot_ms)

    # MOB_HOST_IP at launch uses USB link-local; EPMD may also answer on WiFi.
    devices = resolve_nodes([advertise, scan], bundle_id, prefer_usb: true)

    devices =
      Enum.map(devices, fn d ->
        if d.node, do: d, else: rediscover_node(d, bundle_id)
      end)

    Connector.start_epmd()

    unless Node.alive?() do
      Connector.handle_dist_start(Node.start(:"mob_dev@127.0.0.1", :longnames), cookie)
    end

    devices =
      devices
      |> Enum.with_index()
      |> Enum.map(fn {d, idx} ->
        case Tunnel.setup(d, idx) do
          {:ok, tunneled} -> tunneled
          {:error, reason} -> Mix.raise("tunnel #{d.name}: #{reason}")
        end
      end)

    IO.puts("\n  Connecting nodes...")
    {connected, failed} = connect_pair(devices, cookie)

    if connected == [] do
      Mix.raise("""
      connect failed: #{inspect(Enum.map(failed, & &1.error))}

      Both apps may still be running — use manual bring-up on device:
        iPad: Advertise → Start Advertising → Open #general
        iPhone: Scan → Start Scanning → Open #general
      """)
    end

    if failed != [] do
      IO.puts("  WARNING: could not connect to: #{Enum.map_join(failed, ", ", & &1.name)}")
    end

    if advertise_node = connected_node(connected, advertise_udid) do
      maybe_drive_remote(advertise_node, :advertise, "Pad", connected, scan_udid)
    end

    if scan_node = connected_node(connected, scan_udid) do
      maybe_drive_remote(scan_node, :scan, "Phone", connected, advertise_udid)
    end

    print_summary(connected)
    IO.puts("\nDone — check both screens for messages and readiness banners.\n")
  end

  defp device_for_udid(udid, role) do
    name =
      case System.cmd("ideviceinfo", ["-u", udid, "-k", "DeviceName"], stderr_to_stdout: true) do
        {n, 0} -> String.trim(n)
        _ -> role
      end

    %Device{
      platform: :ios,
      type: :physical,
      serial: udid,
      name: name,
      host_ip: resolve_host_ip(name),
      node: nil,
      status: :discovered
    }
    |> then(&%{&1 | node: Device.node_name(&1)})
  end

  defp host_ip_for_udid(udid) do
    case System.cmd("ideviceinfo", ["-u", udid, "-k", "DeviceName"], stderr_to_stdout: true) do
      {name, 0} -> resolve_host_ip(String.trim(name))
      _ -> nil
    end
  end

  defp resolve_host_ip(device_name) do
    usb_ip_from_mdns(device_name) || usb_ip_for_name(device_name)
  end

  defp usb_ip_for_name(device_name) do
    down = String.downcase(device_name)

    needles =
      [
        String.replace(down, ~r/[^a-z0-9]+/, ""),
        String.replace(down, ~r/[^a-z0-9]+/, "-"),
        String.replace(down, ~r/\s+/, "-")
      ]
      |> Enum.uniq()

    case System.cmd("arp", ["-a"], stderr_to_stdout: true) do
      {out, 0} ->
        lines = out |> String.downcase() |> String.split("\n")

        Enum.find_value(needles, &usb_ip_for_needle(lines, &1))

      _ ->
        nil
    end
  end

  defp usb_ip_for_needle(_lines, ""), do: nil

  defp usb_ip_for_needle(lines, needle) do
    Enum.find_value(lines, fn line ->
      if String.contains?(line, needle), do: usb_ip_from_arp_line(line)
    end)
  end

  defp usb_ip_from_arp_line(line) do
    case Regex.run(~r/\((169\.254\.\d+\.\d+)\)/, line) do
      [_, ip] -> ip
      _ -> nil
    end
  end

  defp usb_ip_from_mdns(device_name) do
    host =
      device_name
      |> String.downcase()
      |> String.replace(~r/\s+/, "-")
      |> Kernel.<>(".local")

    case System.cmd("dscacheutil", ["-q", "host", "-a", "name", host], stderr_to_stdout: true) do
      {out, 0} ->
        out
        |> String.split("\n")
        |> Enum.flat_map(fn line ->
          case Regex.run(~r/ip_address: (\d+\.\d+\.\d+\.\d+)/, line) do
            [_, ip] -> [ip]
            _ -> []
          end
        end)
        |> Enum.sort_by(&ip_preference/1)
        |> List.first()

      _ ->
        nil
    end
  end

  defp ip_preference(ip) do
    case String.split(ip, ".") do
      ["169", "254", _, _] -> 0
      ["192", "168", _, _] -> 1
      _ -> 2
    end
  end

  defp connect_pair(devices, cookie) do
    tasks =
      Enum.map(devices, fn device ->
        {device, Task.async(fn -> wait_node(device, cookie) end)}
      end)

    Enum.reduce(tasks, {[], []}, fn {device, task}, {ok, fail} ->
      IO.write("    #{device.node} ...")

      case Task.await(task, 30_000) do
        {:ok, node} ->
          IO.puts(" ok")
          {ok ++ [%{device | status: :connected, node: node}], fail}

        {:error, reason} ->
          IO.puts(" failed")
          {ok, fail ++ [%{device | status: :error, error: reason}]}
      end
    end)
  end

  defp wait_node(device, cookie) do
    deadline = System.monotonic_time(:millisecond) + 25_000

    wait_node_loop(device, cookie, deadline)
  end

  defp wait_node_loop(device, cookie, deadline) do
    candidates = node_candidates(device)

    case try_connect(candidates, cookie) do
      {:ok, node} ->
        {:ok, node}

      :none ->
        if System.monotonic_time(:millisecond) > deadline do
          {:error, "timeout #{inspect(candidates)}"}
        else
          device =
            case device.host_ip && epmd_node_at(device.host_ip) do
              {:ok, short, port} ->
                %{device | node: :"#{short}@#{device.host_ip}", dist_port: port}

              _ ->
                device
            end

          Process.sleep(500)
          wait_node_loop(device, cookie, deadline)
        end
    end
  end

  defp node_candidates(%Device{node: node, host_ip: ip}) when not is_nil(node) do
    base = Atom.to_string(node) |> String.split("@", parts: 2)

    case base do
      [short, _host] when is_binary(ip) ->
        [node, :"#{short}@#{ip}"]

      _ ->
        [node]
    end
  end

  defp node_candidates(%Device{host_ip: ip}) when is_binary(ip) do
    [:"mob_node_ios@#{ip}"]
  end

  defp node_candidates(_), do: []

  defp try_connect(candidates, cookie) do
    Enum.find_value(candidates, :none, fn node ->
      Node.set_cookie(node, cookie)

      connected? =
        case :net_adm.ping(node) do
          :pong -> true
          _ -> Node.connect(node) == true or node in Node.list()
        end

      if connected?, do: {:ok, node}, else: nil
    end)
    |> case do
      {:ok, node} -> {:ok, node}
      _ -> :none
    end
  end

  defp connected_node(connected, udid) do
    case Enum.find(connected, &(&1.serial == udid)) do
      %{node: node} when not is_nil(node) -> node
      _ -> nil
    end
  end

  defp maybe_drive_remote(node, mode, nickname, connected, other_udid) do
    IO.puts("\n  Driving UI on #{node}...")
    drive_home(node, mode, nickname)
    Process.sleep(3_000)

    IO.puts("  Opening #general...")
    Mob.Test.tap(node, :open_general)
    Process.sleep(2_000)

    if connected_node(connected, other_udid) do
      IO.puts("  Sending test message...")
      send_chat(node, "hello from #{String.downcase(nickname)}")
      Process.sleep(2_000)
    end
  end

  defp drive_home(node, mode, nickname) do
    wait_screen(node, Mob.Node.HomeScreen, 30_000)
    Mob.Test.send_message(node, {:change, :nickname_draft, nickname})
    Mob.Test.tap(node, :save_nickname)

    case mode do
      :advertise ->
        Mob.Test.tap(node, :mode_advertise)

      :scan ->
        Mob.Test.tap(node, :mode_scan)
    end

    Mob.Test.tap(node, :start)
    Process.sleep(1_500)
  end

  defp send_chat(node, text) do
    wait_screen(node, Mob.Node.ChatScreen, 15_000)
    Mob.Test.send_message(node, {:change, :draft, text})
    Mob.Test.tap(node, :send)
    Process.sleep(500)
  end

  defp wait_screen(node, module, timeout_ms) do
    deadline = System.monotonic_time(:millisecond) + timeout_ms

    wait_screen_loop(node, module, deadline)
  end

  defp wait_screen_loop(node, module, deadline) do
    screen = Mob.Test.screen(node)

    if screen == module do
      :ok
    else
      if System.monotonic_time(:millisecond) > deadline do
        Mix.raise("expected #{inspect(module)} on #{inspect(node)}, got #{inspect(screen)}")
      else
        Process.sleep(400)
        wait_screen_loop(node, module, deadline)
      end
    end
  end

  defp print_summary(connected) do
    for %{name: name, node: node} <- connected, not is_nil(node) do
      screen = Mob.Test.screen(node)

      status =
        try do
          Mob.Test.assigns(node).status
        rescue
          _ -> "?"
        end

      msgs = message_count(node)
      IO.puts("  #{name}: screen=#{inspect(screen)} session_status=#{status} messages=#{msgs}")
    end
  end

  defp launch_ok?(:ok), do: true
  defp launch_ok?({:error, _}), do: false

  defp launch_ok?(out),
    do: String.contains?(out, "Launched application") or String.contains?(out, "pid")

  defp launch_device(device, bundle) do
    case launch_physical(device.serial, bundle, device.host_ip) do
      :ok -> {device, :ok}
      {:error, :locked} -> {device, {:error, :locked}}
      {:error, reason} -> {device, {:error, reason}}
    end
  end

  defp launch_physical(udid, bundle, usb_ip) do
    deadline = System.monotonic_time(:second) + 45
    launch_physical_loop(udid, bundle, usb_ip, deadline)
  end

  defp launch_physical_loop(udid, bundle, usb_ip, deadline) do
    {out, _status} = launch_with_usb_ip(udid, bundle, usb_ip)

    cond do
      launch_ok?(out) ->
        :ok

      retryable_launch?(out) ->
        if System.monotonic_time(:second) > deadline do
          {:error, :locked}
        else
          IO.puts("    …retry launch (#{short_udid(udid)}) — unlock device if locked")
          Process.sleep(3_000)
          launch_physical_loop(udid, bundle, usb_ip, deadline)
        end

      true ->
        {:error, String.slice(out, 0, 400)}
    end
  end

  defp retryable_launch?(out) do
    String.contains?(out, "unlocked") or
      String.contains?(out, "failed to launch") or
      String.contains?(out, "FBSOpenApplication") or
      String.contains?(out, "process identifier") or
      String.contains?(out, "error 10004") or
      String.contains?(out, "error 10002")
  end

  defp short_udid(udid), do: String.slice(udid, -8..-1)

  defp launch_with_usb_ip(udid, bundle, usb_ip) do
    env = Jason.encode!(%{"MOB_HOST_IP" => usb_ip})

    System.cmd(
      "xcrun",
      [
        "devicectl",
        "device",
        "process",
        "launch",
        "--terminate-existing",
        "--device",
        udid,
        "--environment-variables",
        env,
        bundle
      ],
      stderr_to_stdout: true
    )
  end

  defp resolve_nodes(devices, bundle_id, opts) do
    prefer_usb? = Keyword.get(opts, :prefer_usb, false)

    Enum.map(devices, fn device ->
      wifi_ip = diag_host_ip(device.serial, bundle_id)

      connect_ip =
        cond do
          prefer_usb? && device.host_ip -> device.host_ip
          wifi_ip -> wifi_ip
          true -> device.host_ip
        end

      case connect_ip && epmd_node_at(connect_ip) do
        {:ok, short_name, dist_port} ->
          node = :"#{short_name}@#{connect_ip}"
          IO.puts("    #{device.name} node #{node} (EPMD on #{connect_ip})")
          %{device | host_ip: connect_ip, node: node, dist_port: dist_port}

        _ ->
          IO.puts(
            "    #{device.name} EPMD not ready on #{connect_ip || "?"} — will retry connect"
          )

          %{device | host_ip: connect_ip}
      end
    end)
  end

  defp diag_host_ip(udid, bundle_id) do
    tmp = Path.join(System.tmp_dir!(), "mob_host_ip_#{udid}.txt")

    case System.cmd(
           "xcrun",
           [
             "devicectl",
             "device",
             "copy",
             "from",
             "--device",
             udid,
             "--domain-type",
             "appDataContainer",
             "--domain-identifier",
             bundle_id,
             "--source",
             "Documents/mob_diag_host_ip.txt",
             "--destination",
             tmp
           ],
           stderr_to_stdout: true
         ) do
      {_, 0} ->
        tmp |> File.read!() |> String.trim() |> empty_to_nil()

      _ ->
        nil
    end
  end

  defp empty_to_nil(""), do: nil
  defp empty_to_nil(s), do: s

  defp rediscover_node(device, bundle_id) do
    ips =
      [
        device.host_ip,
        diag_host_ip(device.serial, bundle_id),
        usb_ip_from_mdns(device.name)
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    Enum.find_value(ips, device, fn ip ->
      case epmd_node_at(ip) do
        {:ok, short, port} ->
          %{device | host_ip: ip, node: :"#{short}@#{ip}", dist_port: port}

        _ ->
          nil
      end
    end)
  end

  # BEAM :gen_tcp to device IPs can return :ehostunreach on some macOS builds while
  # `/usr/bin/nc` works; use nc for EPMD name listing during bring-up.
  defp epmd_node_at(ip) do
    script = "printf '\\000\\001n' | nc -w 2 #{ip} 4369 2>/dev/null"

    case System.cmd("sh", ["-c", script], stderr_to_stdout: true) do
      {out, 0} ->
        out
        |> String.split("\n")
        |> Enum.find_value(fn line ->
          case Regex.run(~r/name ([a-z0-9_]+_ios[^\s]*) at port (\d+)/i, line) do
            [_, short_name, port] -> {:ok, short_name, String.to_integer(port)}
            _ -> nil
          end
        end)

      _ ->
        nil
    end
  end

  defp message_count(node) do
    case Mob.Test.screen(node) do
      Mob.Node.ChatScreen ->
        try do
          Mob.Test.assigns(node).snapshot.message_count
        rescue
          _ -> 0
        end

      _ ->
        0
    end
  end
end
