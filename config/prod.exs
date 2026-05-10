import Config

config :meshx_store,
       :data_dir,
       System.get_env("MESHX_STORE_DATA_DIR", Path.expand("../var/meshx_store_prod", __DIR__))
