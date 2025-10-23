# config/config.exs
import Config

config :provider_vault_cli, ProviderVault.Repo,
  database: "provider_vault_cli_repo",
  username: "donfox1",
  password: "",
  hostname: "localhost",
  port: 5432

# General application configuration
config :provider_vault_cli,
  ecto_repos: [ProviderVault.Repo]

config :logger, :default_handler, level: :info

# 🔽 This line is required so dev.exs / test.exs / prod.exs get loaded
import_config "#{config_env()}.exs"
