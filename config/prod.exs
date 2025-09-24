# config/prod.exs
import Config

# Production-specific settings for ProviderVault CLI
config :provider_vault_cli,
  # Where to store provider data CSVs in production
  # (adjust this path to match your server environment)
  data_dir: "/var/lib/provider_vault/data"

# Logger config for production: less verbose
config :logger,
  level: :info,
  backends: [:console],
  compile_time_purge_matching: [
    [level_lower_than: :info]
  ]
