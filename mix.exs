# mix.exs
defmodule ProviderVaultCli.MixProject do
  use Mix.Project

  def project do
    [
      app: :provider_vault_cli,
      version: "1.7.0",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,

      # Build as a standalone executable with `mix escript.build`
      escript: [main_module: ProviderVault.MixRunner],
      deps: deps(),
      aliases: aliases(),

      # Documentation settings (for `mix docs`, optional)
      docs: [
        # landing page module
        main: "ProviderVault.CLI",
        source_url: "https://github.com/donfox/provider_vault_cli",
        extras: ["README.md"]
      ],

      # Run docs in dev by default
      preferred_cli_env: [docs: :dev]
    ]
  end

  def application do
    [
      mod: {ProviderVaultCli.Application, []},
      extra_applications: [:logger, :inets, :ssl]
    ]
  end

  # Compile test support files only in test env
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:nimble_csv, "~> 1.3"},
      # ex_doc is the tool that generates HTML docs from your @moduledoc/@doc
      # We only want it while developing, not in prod or test.
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      # Database dependencies
      {:ecto_sql, "~> 3.12"},
      {:postgrex, "~> 0.19"}
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
