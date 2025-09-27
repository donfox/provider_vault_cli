defmodule ProviderVault.MixRunner do
  @moduledoc """
  Entry point for the ProviderVault CLI when built as an escript.

  This module is invoked automatically when the compiled `provider_vault_cli`
  binary is executed. It receives the command-line arguments (`argv`) and
  hands them off to the real CLI logic in `ProviderVault.CLI.Main`.

  Responsibilities:
    * Ensure required OTP applications (like `:inets` and `:ssl`) are started,
      because escripts do not automatically boot them.
    * Delegate execution to `ProviderVault.CLI.Main.main/1`.

  Example:
      $ ./provider_vault_cli --help
      # calls `ProviderVault.MixRunner.main(["--help"])`
      # which then calls `ProviderVault.CLI.Main.main/1`
  """

  def main(argv) do
    ensure_started!([:inets, :ssl])
    ProviderVault.CLI.Main.main(argv)
  end

  defp ensure_started!(apps) do
    Enum.each(apps, fn app ->
      :application.ensure_all_started(app)
    end)
  end
end
