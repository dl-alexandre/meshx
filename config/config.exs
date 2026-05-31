# This file is responsible for configuring your umbrella
# and **all applications** and their dependencies with the
# help of the Config module.
#
# Note that all applications in your umbrella share the
# same configuration and dependencies, which is why they
# all use the same configuration file. If you want different
# configurations or dependencies per app, it is best to
# move said applications out of the umbrella.
import Config

config :mob_runtime, discovery: [enabled?: false]
config :mob_runtime, flow_control: [send_window: 8, queue_limit: 256]

config :mob_store, trust_policy: :tofu

import_config "#{config_env()}.exs"
