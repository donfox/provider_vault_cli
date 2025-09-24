defmodule ProviderVault.MixRunner do
  @moduledoc false
  @callback run(task :: String.t(), args :: [String.t()]) :: any()
end

defmodule ProviderVault.MixRunner.Real do
  @moduledoc false
  @behaviour ProviderVault.MixRunner
  @impl true
  def run(task, args), do: Mix.Task.run(task, args)
end
