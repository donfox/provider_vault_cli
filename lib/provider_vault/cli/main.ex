defmodule ProviderVault.CLI.Main do
  @moduledoc """
  Top-level entry point for the ProviderVault CLI.

  Responsibilities:
    * Handle top-level CLI args (`--help`, `--version`).
    * Delegate to the interactive menu (`ProviderVault.CLI.Menu.main/0`).
    * Provide a `start/0` wrapper for convenience in IEx or Mix tasks.
  """

  # Silence compile-time warning when Menu hasn't been compiled yet.
  @compile {:no_warn_undefined, ProviderVault.CLI.Menu}

  @type argv :: [String.t()]

  @spec main(argv()) :: :ok | {:error, term()}
  def main(argv \\ []) do
    cond do
      "--help" in argv or "-h" in argv ->
        print_help()
        :ok

      "--version" in argv or "-v" in argv ->
        print_version()
        :ok

      true ->
        ProviderVault.CLI.Menu.main()
    end
  end

  @doc "Convenience wrapper for interactive mode (same as main([]))."
  @spec start() :: :ok | {:error, term()}
  def start, do: main([])

  defp print_help do
    IO.puts("""
    Provider Vault CLI

    Usage:
      provider_vault_cli [--help | --version]

    Without flags, an interactive menu will be shown.
    """)
  end

  defp print_version do
    config = Mix.Project.config()
    IO.puts("#{config[:app]} #{config[:version]}")
  end
end
