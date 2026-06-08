defmodule Mix.Tasks.Mob.Node.PushDevice do
  @shortdoc "Push compiled BEAMs to one physical iOS device by UDID (devicectl)"

  @moduledoc """
  Hot-deploy BEAMs to a physical iPhone/iPad when `mix mob.deploy` does not list it.

  The native app must already be installed (`mix mob.node.deploy_device`).

      mix mob.node.push_device --device 00008030-000209510ED0C02E
  """

  use Mix.Task

  alias MobDev.Discovery.IOS
  alias MobDev.Device
  alias MobDev.HotPush

  @switches [device: :string, no_restart: :boolean]

  @impl Mix.Task
  def run(args) do
    {opts, _, invalid} = OptionParser.parse(args, switches: @switches)

    if invalid != [] do
      Mix.raise("Invalid options: #{inspect(invalid)}")
    end

    udid = opts[:device] || Mix.raise("Usage: mix mob.node.push_device --device <udid>")
    restart? = not Keyword.get(opts, :no_restart, false)

    Mix.Task.run("compile")

    name =
      case System.cmd("ideviceinfo", ["-u", udid, "-k", "DeviceName"], stderr_to_stdout: true) do
        {n, 0} -> String.trim(n)
        _ -> "iOS device"
      end

    device = %Device{
      platform: :ios,
      type: :physical,
      serial: udid,
      name: name,
      status: :discovered
    }

    IO.puts("Pushing BEAMs to #{name} (#{udid})...")

    case push_physical(device) do
      :ok ->
        if restart? do
          bundle = MobDev.Config.bundle_id()
          IOS.terminate_app(udid, bundle)
          Process.sleep(300)
          IOS.launch_app(udid, bundle)
        end

        IO.puts("Done.")

      {:error, reason} ->
        Mix.raise(reason)
    end
  end

  defp push_physical(%Device{serial: udid}) do
    app = Mix.Project.config()[:app] |> to_string()
    bundle = MobDev.Config.bundle_id()
    beam_dirs = HotPush.runtime_beam_dirs()

    staging_parent =
      Path.join(System.tmp_dir!(), "mob_ios_push_#{:erlang.unique_integer([:positive])}")

    staging_dir = Path.join(staging_parent, app)
    File.mkdir_p!(staging_dir)

    try do
      Enum.each(beam_dirs, fn dir ->
        case System.cmd("cp", ["-r", "#{Path.expand(dir)}/.", staging_dir],
               stderr_to_stdout: true
             ) do
          {_, 0} -> :ok
          {out, _} -> throw({:error, "cp failed: #{out}"})
        end
      end)

      priv = Path.join(File.cwd!(), "priv")

      if File.dir?(priv) do
        priv_dest = Path.join(staging_dir, "priv")
        File.mkdir_p!(priv_dest)
        System.cmd("cp", ["-r", "#{priv}/.", priv_dest], stderr_to_stdout: true)
      end

      case System.cmd(
             "xcrun",
             [
               "devicectl",
               "device",
               "copy",
               "to",
               "--device",
               udid,
               "--domain-type",
               "appDataContainer",
               "--domain-identifier",
               bundle,
               "--source",
               staging_dir,
               "--destination",
               "Documents/otp/#{app}"
             ],
             stderr_to_stdout: true
           ) do
        {_, 0} -> :ok
        {out, _} -> throw({:error, "devicectl copy failed: #{out}"})
      end
    catch
      {:error, reason} -> {:error, reason}
    after
      File.rm_rf(staging_parent)
    end
  end
end
