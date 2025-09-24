# config/dev.exs
import Config

# Development-specific settings for ProviderVault CLI
config :provider_vault_cli,
  # Default directory where provider data CSVs will be stored in dev
  data_dir: "priv/data"

# Logger config for development: more verbose
config :logger,
  level: :debug,
  backends: [:console],
  compile_time_purge_matching: []
