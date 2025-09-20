defmodule Mix.Tasks.Provider.Start do
  use Mix.Task

  @shortdoc "Starts the Provider Vault CLI"
  def run(_args) do
    # Ensure your app and deps are started when debugging
    Mix.Task.run("app.start")
    ProviderVault.CLI.Main.start()
  end
end
