defmodule ProviderVaultCli.MixProject do
  use Mix.Project

  def project do
    [
      app: :provider_vault_cli,
      version: "0.1.6",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:nimble_csv, "~> 1.3"},
      {:xlsxir, "~> 1.6"}
    ]
  end

  defp aliases do
    [
      check: ["format --check-formatted", "compile", "test"],
      setup: ["deps.get", "check"],
      start: ["provider.start"]
    ]
  end

  def cli do
    [
      preferred_envs: [
        check: :test,
        setup: :test
      ]
    ]
  end
end
