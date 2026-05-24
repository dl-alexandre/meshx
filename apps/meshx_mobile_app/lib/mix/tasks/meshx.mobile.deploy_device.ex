defmodule Mix.Tasks.Meshx.Mobile.DeployDevice do
  use Mix.Task

  @shortdoc "Build and install the MeshX Mob app on a physical iOS device"

  @switches [device: :string, slim: :boolean]

  @impl Mix.Task
  def run(args) do
    {opts, _argv, invalid} = OptionParser.parse(args, switches: @switches)

    if invalid != [] do
      Mix.raise("Invalid options: #{inspect(invalid)}")
    end

    device = opts[:device] || Mix.raise("Usage: mix meshx.mobile.deploy_device --device <udid>")

    mix = System.find_executable("mix") || "mix"
    System.cmd(mix, ["deps.get"], into: IO.stream())
    Mix.Task.run("compile")

    with {:ok, cfg} <- signed_config(),
         {:ok, otp_root} <- MobDev.OtpDownloader.ensure_ios_device(),
         {:ok, python_bundle} <- maybe_ensure_python_bundle() do
      script =
        cfg
        |> generate_build_device_sh(otp_root)
        |> MeshxMobileApp.IOSDeviceBuild.bridge_linked_script()

      script_path = Path.join(["ios", "build_device_meshx.sh"])
      File.write!(script_path, script)
      File.chmod!(script_path, 0o755)

      env = build_device_env(cfg, otp_root, python_bundle, opts)

      case System.cmd("bash", [script_path, device],
             env: env,
             stderr_to_stdout: true,
             into: IO.stream()
           ) do
        {_, 0} ->
          IO.puts("MeshX Mob device build installed on #{device}")

        {_, _} ->
          Mix.raise("MeshX Mob device build failed; check output above")
      end
    else
      {:error, reason} -> Mix.raise(reason)
    end
  end

  defp signed_config do
    cfg =
      MobDev.Config.load_mob_config()
      |> Keyword.put_new(:mob_dir, Path.join(File.cwd!(), "deps/mob"))
      |> Keyword.put_new(:elixir_lib, default_elixir_lib())
      |> Keyword.put(:bundle_id, MobDev.Config.bundle_id())

    with {:ok, identity} <- resolve_sign_identity(cfg[:ios_sign_identity]),
         {:ok, {profile_uuid, team_id}} <-
           resolve_profile_uuid(cfg[:ios_profile_uuid], cfg[:bundle_id], cfg[:ios_team_id]) do
      {:ok,
       cfg
       |> Keyword.put(:ios_sign_identity, identity)
       |> Keyword.put(:ios_profile_uuid, profile_uuid)
       |> Keyword.put(:ios_team_id, team_id)}
    end
  end

  defp default_elixir_lib do
    System.get_env("MOB_ELIXIR_LIB") ||
      :elixir |> :code.lib_dir() |> to_string() |> Path.dirname()
  end

  defp resolve_sign_identity(identity) when is_binary(identity), do: {:ok, identity}

  defp resolve_sign_identity(_identity) do
    case System.cmd("security", ["find-identity", "-v", "-p", "codesigning"],
           stderr_to_stdout: true
         ) do
      {output, 0} ->
        identities =
          Regex.scan(~r/\d+\) [0-9A-F]+ "([^"]+)"/, output)
          |> Enum.map(fn [_, full] -> full end)
          |> Enum.filter(&String.contains?(&1, "Apple Development"))
          |> Enum.uniq()

        case identities do
          [] ->
            {:error, "No Apple Development signing identity found in the keychain."}

          [identity] ->
            IO.puts("Auto-detected signing identity: #{identity}")
            {:ok, identity}

          many ->
            {:error,
             "Multiple Apple Development signing identities found; set ios_sign_identity in mob.exs.\n" <>
               Enum.map_join(many, "\n", &"  #{&1}")}
        end

      {output, _status} ->
        {:error, "security find-identity failed: #{output}"}
    end
  end

  defp resolve_profile_uuid(uuid, _bundle_id, team_id)
       when is_binary(uuid) and is_binary(team_id),
       do: {:ok, {uuid, team_id}}

  defp resolve_profile_uuid(uuid, bundle_id, _team_id) do
    profiles =
      [
        Path.expand("~/Library/Developer/Xcode/UserData/Provisioning Profiles"),
        Path.expand("~/Library/MobileDevice/Provisioning Profiles")
      ]
      |> Enum.flat_map(&Path.wildcard(Path.join(&1, "*.mobileprovision")))
      |> Enum.flat_map(&MobDev.Release.parse_mobileprovision/1)
      |> Enum.filter(& &1.provisioned_devices?)

    exact_profiles = Enum.filter(profiles, &String.ends_with?(&1.app_id, ".#{bundle_id}"))

    profiles =
      case exact_profiles do
        [] -> Enum.filter(profiles, &String.ends_with?(&1.app_id, ".*"))
        matches -> matches
      end

    candidates = if is_binary(uuid), do: Enum.filter(profiles, &(&1.uuid == uuid)), else: profiles

    case candidates do
      [] ->
        {:error, "No iOS Development provisioning profile found for #{bundle_id}."}

      [%{uuid: found_uuid, app_id: app_id, team_id: team_id}] ->
        IO.puts("Auto-detected Development profile: #{found_uuid} (#{app_id})")
        {:ok, {found_uuid, team_id}}

      many ->
        choices = Enum.map_join(many, "\n", &"  #{&1.uuid} (#{&1.app_id})")

        {:error,
         "Multiple Development profiles match #{bundle_id}; set ios_profile_uuid in mob.exs.\n#{choices}"}
    end
  end

  defp maybe_ensure_python_bundle do
    if MobDev.NativeBuild.pythonx_in_project?() do
      MobDev.PythonAppleSupport.ensure()
    else
      {:ok, nil}
    end
  end

  defp generate_build_device_sh(cfg, otp_root) do
    with {:module, module} <- Code.ensure_loaded(MobDev.NativeBuild),
         true <- function_exported?(module, :generate_build_device_sh, 2) do
      apply(module, :generate_build_device_sh, [cfg, otp_root])
    else
      _ ->
        Mix.raise("""
        MobDev.NativeBuild.generate_build_device_sh/2 is not available in this mob_dev version.
        Use `mix mob.deploy --native --platform ios --device <udid>` or migrate
        meshx.mobile.deploy_device to the current Mob native build pipeline.
        """)
    end
  end

  defp build_device_env(cfg, otp_root, python_bundle, opts) do
    app_atom = Mix.Project.config()[:app]
    slim_flag = if Keyword.get(opts, :slim, false), do: "1", else: "0"

    base = [
      {"MOB_DIR", Path.expand(cfg[:mob_dir])},
      {"MOB_ELIXIR_LIB", Path.expand(cfg[:elixir_lib])},
      {"MOB_IOS_DEVICE_OTP_ROOT", otp_root},
      {"MOB_IOS_EPMD_BUILD_SRC", cfg[:ios_epmd_build_src] || otp_root},
      {"MOB_IOS_BUNDLE_ID", cfg[:bundle_id]},
      {"MOB_IOS_TEAM_ID", cfg[:ios_team_id]},
      {"MOB_IOS_SIGN_IDENTITY", cfg[:ios_sign_identity]},
      {"MOB_IOS_PROFILE_UUID", cfg[:ios_profile_uuid]},
      {"MOB_APP_NAME", app_atom |> to_string() |> Macro.camelize()},
      {"MOB_APP_MODULE", to_string(app_atom)},
      {"MOB_SLIM", slim_flag}
    ]

    case python_bundle do
      bundle when is_binary(bundle) -> [{"PYTHON_APPLE_SUPPORT", bundle} | base]
      _bundle -> base
    end
  end
end
