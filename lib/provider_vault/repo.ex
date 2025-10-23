defmodule ProviderVault.Repo do
  use Ecto.Repo,
    otp_app: :provider_vault_cli,
    adapter: Ecto.Adapters.Postgres
end
