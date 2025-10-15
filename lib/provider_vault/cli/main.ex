defmodule ProviderVault.CLI.Main do
  @moduledoc "Top-level CLI launcher."

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
        # Keep it simple: call the menu directly.
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
    # Works in escript (no Mix dependency):
    vsn =
      case Application.spec(:provider_vault_cli, :vsn) do
        nil -> "dev"
        v when is_list(v) -> List.to_string(v)
        v -> to_string(v)
      end

    app =
      case Application.spec(:provider_vault_cli, :applications) do
        _ -> "provider_vault_cli"
      end

    IO.puts("#{app} #{vsn}")
  end
end
