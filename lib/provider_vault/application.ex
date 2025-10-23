defmodule ProviderVaultCli.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ProviderVault.Repo
    ]

    opts = [strategy: :one_for_one, name: ProviderVaultCli.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
