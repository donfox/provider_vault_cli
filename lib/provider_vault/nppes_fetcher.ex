defmodule ProviderVault.NppesFetcher do
  @moduledoc """
  Downloads and extracts NPPES monthly ZIP data.
  """

  @base_url "https://download.cms.gov/nppes"
  @month_map %{
    1 => "JANUARY",
    2 => "FEBRUARY",
    3 => "MARCH",
    4 => "APRIL",
    5 => "MAY",
    6 => "JUNE",
    7 => "JULY",
    8 => "AUGUST",
    9 => "SEPTEMBER",
    10 => "OCTOBER",
    11 => "NOVEMBER",
    12 => "DECEMBER"
  }

  @doc """
  Fetch a ZIP file from a given URL to the given destination.
  """
  @spec fetch!(String.t(), keyword()) :: String.t()
  def fetch!(url, opts) when is_binary(url) and is_list(opts) do
    dest_dir = Keyword.get(opts, :to, "priv/data")
    File.mkdir_p!(dest_dir)

    file_name = Path.basename(url)
    local_path = Path.join(dest_dir, file_name)

    download!(url, local_path)
    IO.puts("→ Extracting ZIP to #{dest_dir} ...")
    unzip(local_path, dest_dir)

    local_path
  end

  @doc """
  Fetches the current month’s NPPES ZIP file based on today’s date.
  Downloads it into "priv/data".
  """
  @spec fetch_current_month!() :: String.t()
  def fetch_current_month!() do
    {month, year} = current_month_and_year()
    month_name = Map.fetch!(@month_map, month)

    file = "NPPES_Data_Dissemination_#{month_name}_#{year}.zip"
    url = "#{@base_url}/#{file}"

    fetch!(url, to: "priv/data")
  end

  # --- internal helpers ---

  defp current_month_and_year do
    %{month: m, year: y} = Date.utc_today()
    {m, y}
  end

  defp download!(url, path) do
    IO.puts("→ Downloading #{url} ...")

    case :httpc.request(:get, {String.to_charlist(url), []}, [], [
           {:stream, String.to_charlist(path)}
         ]) do
      {:ok, _} ->
        :ok

      {:error, {:failed_connect, _}} ->
        raise "Failed to connect. Check URL: #{url}"

      {:error, {:http_error, 404}} ->
        raise "File not found at URL: #{url}"

      {:error, reason} ->
        raise "Download failed: #{inspect(reason)}"
    end
  end

  defp unzip(zip_path, dest_dir) do
    {output, exit_code} =
      System.cmd("unzip", ["-o", zip_path, "-d", dest_dir], stderr_to_stdout: true)

    if exit_code != 0 do
      raise "Unzip failed: #{output}"
    end
  end
end
