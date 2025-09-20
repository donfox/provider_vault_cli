defmodule ProviderVault.Ingestion.NppesFetcher do
  @moduledoc "Minimal downloader for a single NPPES datafile via curl fallback."
  @default_dir "priv/data"

  def fetch!(url, opts \\ []) when is_binary(url) do
    to_dir = Keyword.get(opts, :to, @default_dir)

    filename =
      case Keyword.get(opts, :as) do
        nil -> url |> URI.parse() |> Map.get(:path) |> Path.basename()
        name -> name
      end

    File.mkdir_p!(to_dir)
    out_path = Path.join(to_dir, filename)

    # -f: fail on HTTP errors | -L: follow redirects | --silent --show-error: clean logs
    {_, exit_code} =
      System.cmd("curl", ["-fL", "--silent", "--show-error", "-o", out_path, url],
        into: IO.stream(:stdio, :line)
      )

    if exit_code == 0 do
      out_path
    else
      raise "curl failed (exit #{exit_code}) for #{url}"
    end
  end
end
