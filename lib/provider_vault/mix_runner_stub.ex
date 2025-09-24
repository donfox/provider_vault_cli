defmodule ProviderVault.MixRunner.Stub do
  @behaviour ProviderVault.MixRunner
  @impl true
  def run(task, args) do
    IO.puts("STUB_RUN #{task} #{Enum.join(args, " ")}")
    :ok
  end
end
