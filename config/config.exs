# config/config.exs
import Config

# General application configuration
config :provider_vault_cli,
  # If you add Ecto in the future, list repos here.
  ecto_repos: []

# 🔽 This line is required so dev.exs / test.exs / prod.exs get loaded
import_config "#{config_env()}.exs"

# You can set defaults that apply in all environments.
# For example:
#
# config :provider_vault_cli,
#   data_dir: "priv/data"
#
# These can be overridden in config/dev.exs, config/test.exs, config/prod.exs.
