# mob.exs — local Mob build environment configuration.
# Copy this file to mob.exs and adjust paths for your machine.

import Config

config :mob_dev,
  mob_dir: Path.join(File.cwd!(), "deps/mob"),
  elixir_lib: System.get_env("MOB_ELIXIR_LIB", :code.lib_dir(:elixir) |> to_string() |> Path.dirname())
