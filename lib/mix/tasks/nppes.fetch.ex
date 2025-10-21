defmodule Mix.Tasks.Nppes.Fetch do
  use Mix.Task

  @shortdoc "Download a current NPPES datafile from a URL"
  @moduledoc """
  Usage:
      mix nppes.fetch URL [--to DIR] [--as FILENAME]

  Or via env:
      NPPES_URL=https://... mix nppes.fetch

  Examples:
      mix nppes.fetch https://download.cms.gov/nppes/NPPES_Data_Dissemination_Aug2025.zip --to priv/data
      mix nppes.fetch https://.../file.zip --as nppes_current.zip
  """

  @impl true
  def run(args) do
    Mix.Task.run("app.start")

    {opts, rest, _} =
      OptionParser.parse(args,
        strict: [to: :string, as: :string]
      )

    url =
      case rest do
        [u | _] -> u
        _ -> System.get_env("NPPES_URL")
      end || Mix.raise("Provide URL arg or set NPPES_URL")

    path =
      ProviderVault.NppesFetcher.fetch!(url,
        to: opts[:to] || "priv/data",
        as: opts[:as]
      )

    Mix.shell().info("✅ Downloaded to #{path}")
  end
end
