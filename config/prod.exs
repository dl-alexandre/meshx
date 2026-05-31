import Config

config :mob_store,
       :data_dir,
       System.get_env("MESHX_STORE_DATA_DIR", Path.expand("../var/mob_store_prod", __DIR__))
