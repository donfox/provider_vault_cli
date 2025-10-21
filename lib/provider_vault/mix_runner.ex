defmodule ProviderVault.MixRunner do
  @moduledoc """
  Escript entry point for ProviderVault CLI.

  Called when the compiled `provider_vault_cli` binary runs. It ensures
  network apps are started and then delegates to `ProviderVault.CLI.Main`.
  """

  @type argv :: [String.t()]

  @spec main(argv()) :: :ok | no_return()
  def main(argv \\ []) do
    ensure_started!([:inets, :ssl])

    case ProviderVault.CLI.main(argv) do
      :ok ->
        # ← Changed
        System.halt(0)

      {:error, reason} ->
        IO.puts(:stderr, "Error: #{inspect(reason)}")
        System.halt(1)
    end
  end

  # Start required OTP apps; raise if any fail so the escript exits clearly.
  defp ensure_started!(apps) do
    Enum.each(apps, fn app ->
      case :application.ensure_all_started(app) do
        {:ok, _started} ->
          :ok

        {:error, reason} ->
          IO.puts(:stderr, "Failed to start #{app}: #{inspect(reason)}")
          System.halt(1)
      end
    end)
  end
end
