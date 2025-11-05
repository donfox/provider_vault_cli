# config/config.exs
# ← THIS LINE IS REQUIRED!
import Config

config :provider_vault_cli, ProviderVault.Repo,
  database: System.get_env("DATABASE_NAME") || "provider_vault_cli_repo",
  username: System.get_env("DATABASE_USER") || "postgres",
  password: System.get_env("DATABASE_PASSWORD") || "",
  hostname: System.get_env("DATABASE_HOST") || "localhost",
  port: String.to_integer(System.get_env("DATABASE_PORT") || "5432")

config :provider_vault_cli,
  ecto_repos: [ProviderVault.Repo]

config :logger, :default_handler, level: :info
