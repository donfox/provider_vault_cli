defmodule Mix.Tasks.Provider.Start do
  use Mix.Task
  @shortdoc "Starts the Provider Vault interactive CLI"

  @moduledoc """
  Runs the interactive CLI (same as running the escript without flags).
  """

  @impl Mix.Task
  def run(_argv) do
    Application.ensure_all_started(:inets)
    Application.ensure_all_started(:ssl)
    ProviderVault.CLI.main([])
  end
end
