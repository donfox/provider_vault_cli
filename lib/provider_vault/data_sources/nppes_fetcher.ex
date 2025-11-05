defmodule ProviderVault.DataSources.NPPESFetcher do
  @moduledoc """
  Fetches provider data from the NPPES (National Plan and Provider Enumeration System) database.

  This module downloads the NPPES CSV file, extracts it, and returns a sample of provider records.
  NPPES is the official registry of all healthcare providers in the United States.

  ## Usage

      {:ok, providers} = NPPESFetcher.fetch()
      # Returns list of 15 provider maps
  """

  require Logger

  @source_name "NPPES"
  @download_dir "nppes_downloads"

  # NPPES weekly update file (smaller than full file)
  # Full file URL: https://download.cms.gov/nppes/NPPES_Data_Dissemination_XXXXX.zip
  @nppes_url "https://download.cms.gov/nppes/NPPES_Deactivated_NPI_Report_XXXXX.zip"

  # For testing/demo, we'll use a smaller sample endpoint
  # In production, you'd use the actual NPPES URL above
  @test_mode true

  @doc """
  Fetches provider data from NPPES.
  Returns {:ok, providers} or {:error, reason}.
  """
  def fetch do
    Logger.info("[#{@source_name}] Starting fetch...")
    start_time = System.monotonic_time(:millisecond)

    result =
      if @test_mode do
        # Generate sample NPPES-like data for demo purposes
        generate_sample_data()
      else
        # Real NPPES download and processing
        fetch_real_nppes_data()
      end

    elapsed = System.monotonic_time(:millisecond) - start_time

    case result do
      {:ok, providers} ->
        Logger.info("[#{@source_name}] Fetched #{length(providers)} providers in #{elapsed}ms")
        {:ok, providers}

      {:error, reason} ->
        Logger.error("[#{@source_name}] Fetch failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Generate sample NPPES-like data (for demo/testing)
  defp generate_sample_data do
    # Simulate network delay
    Process.sleep(500 + :rand.uniform(500))

    providers =
      1..15
      |> Enum.map(fn i ->
        npi = "15000000#{String.pad_leading(to_string(i), 2, "0")}"

        %{
          npi: npi,
          first_name: Enum.random(~w(John Jane Michael Sarah David Emily)),
          last_name: Enum.random(~w(Smith Johnson Williams Brown Jones Garcia Miller Davis)),
          credential: Enum.random(~w(MD DO NP PA)),
          specialty:
            Enum.random([
              "Family Medicine",
              "Internal Medicine",
              "Pediatrics",
              "Cardiology",
              "Orthopedics"
            ]),
          address: "#{100 + i} Medical Center Dr",
          city: Enum.random(~w(Houston Dallas Austin Miami Orlando)),
          state: Enum.random(~w(TX FL CA NY PA)),
          zip: "#{10000 + i * 100}",
          phone: "(555) 0#{String.pad_leading(to_string(100 + i), 2, "0")}-0000",
          source: @source_name
        }
      end)

    {:ok, providers}
  end

  # Real NPPES data fetching (for production use)
  defp fetch_real_nppes_data do
    with {:ok, zip_path} <- download_nppes_file(),
         {:ok, csv_path} <- extract_zip(zip_path),
         {:ok, providers} <- parse_csv(csv_path) do
      # Cleanup temp files
      cleanup_files([zip_path, csv_path])

      {:ok, providers}
    else
      error -> error
    end
  end

  defp download_nppes_file do
    Logger.info("[#{@source_name}] Downloading NPPES file...")

    # Create download directory
    File.mkdir_p!(@download_dir)

    zip_path = Path.join(@download_dir, "nppes_#{System.system_time(:second)}.zip")

    # Use :httpc for HTTP download (built-in, no extra dependencies)
    case :httpc.request(:get, {@nppes_url, []}, [], stream: String.to_charlist(zip_path)) do
      {:ok, :saved_to_file} ->
        Logger.info("[#{@source_name}] Download complete")
        {:ok, zip_path}

      {:error, reason} ->
        {:error, "Download failed: #{inspect(reason)}"}
    end
  end

  defp extract_zip(zip_path) do
    Logger.info("[#{@source_name}] Extracting ZIP file...")

    case :zip.unzip(String.to_charlist(zip_path), cwd: String.to_charlist(@download_dir)) do
      {:ok, files} ->
        # Find the CSV file
        csv_file =
          files
          |> Enum.map(&to_string/1)
          |> Enum.find(&String.ends_with?(&1, ".csv"))

        if csv_file do
          {:ok, csv_file}
        else
          {:error, "No CSV file found in archive"}
        end

      {:error, reason} ->
        {:error, "Extraction failed: #{inspect(reason)}"}
    end
  end

  defp parse_csv(csv_path) do
    Logger.info("[#{@source_name}] Parsing CSV file...")

    try do
      providers =
        csv_path
        |> File.stream!()
        # Skip header
        |> Stream.drop(1)
        # Take only 15 records
        |> Stream.take(15)
        |> Stream.map(&parse_nppes_line/1)
        |> Enum.reject(&is_nil/1)

      {:ok, providers}
    rescue
      e -> {:error, "CSV parsing failed: #{Exception.message(e)}"}
    end
  end

  # Parse NPPES CSV line
  # NPPES format has many columns - we extract the ones we need
  # Column positions (0-indexed):
  # 0: NPI, 5: First Name, 6: Last Name, 47: Primary Specialty
  defp parse_nppes_line(line) do
    fields =
      line
      |> String.trim()
      |> String.split(",")
      |> Enum.map(&String.trim(&1, "\""))

    try do
      %{
        npi: Enum.at(fields, 0),
        first_name: Enum.at(fields, 5) || "",
        last_name: Enum.at(fields, 6) || "",
        credential: extract_credential(Enum.at(fields, 10)),
        specialty: Enum.at(fields, 47) || "General Practice",
        address: Enum.at(fields, 28) || "",
        city: Enum.at(fields, 29) || "",
        state: Enum.at(fields, 30) || "",
        zip: Enum.at(fields, 31) || "",
        phone: format_phone(Enum.at(fields, 34)),
        source: @source_name
      }
    rescue
      _ -> nil
    end
  end

  defp extract_credential(nil), do: "MD"

  defp extract_credential(text) when is_binary(text) do
    cond do
      String.contains?(text, "MD") -> "MD"
      String.contains?(text, "DO") -> "DO"
      String.contains?(text, "NP") -> "NP"
      String.contains?(text, "PA") -> "PA"
      true -> "MD"
    end
  end

  defp format_phone(nil), do: ""

  defp format_phone(phone) when is_binary(phone) do
    # Basic phone formatting
    digits = String.replace(phone, ~r/\D/, "")

    if String.length(digits) == 10 do
      "(#{String.slice(digits, 0..2)}) #{String.slice(digits, 3..5)}-#{String.slice(digits, 6..9)}"
    else
      phone
    end
  end

  defp cleanup_files(paths) do
    Enum.each(paths, fn path ->
      if File.exists?(path) do
        File.rm(path)
        Logger.debug("[#{@source_name}] Cleaned up: #{path}")
      end
    end)
  end
end
