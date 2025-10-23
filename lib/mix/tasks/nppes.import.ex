defmodule Mix.Tasks.Nppes.Import do
  use Mix.Task
  require Logger

  alias ProviderVault.{Repo, Provider}
  alias NimbleCSV.RFC4180, as: CSV

  @shortdoc "Import NPPES CSV data into database"

  @moduledoc """
  Import NPPES provider data from CSV into the database.

  ## Usage

      # Import first 30 records (testing)
      mix nppes.import priv/data/npidata_pfile_20050523-20251012.csv --limit 30

      # Import first 1000 records
      mix nppes.import priv/data/npidata_pfile_20050523-20251012.csv --limit 1000

      # Import all records (WARNING: 7+ million records, takes hours!)
      mix nppes.import priv/data/npidata_pfile_20050523-20251012.csv

  ## Options

      --limit N     Import only first N records (default: 30)
      --batch SIZE  Batch size for inserts (default: 1000)
  """

  @impl Mix.Task
  def run(args) do
    # Start the app and Repo
    Mix.Task.run("app.start")

    {opts, paths, _} =
      OptionParser.parse(args,
        strict: [limit: :integer, batch: :integer],
        aliases: [l: :limit, b: :batch]
      )

    csv_path = List.first(paths)
    limit = Keyword.get(opts, :limit, 30)
    batch_size = Keyword.get(opts, :batch, 1000)

    unless csv_path && File.exists?(csv_path) do
      Mix.raise("CSV file not found. Usage: mix nppes.import <path/to/file.csv>")
    end

    Logger.info("=" |> String.duplicate(60))
    Logger.info("NPPES Import Starting")
    Logger.info("=" |> String.duplicate(60))
    Logger.info("File: #{csv_path}")
    Logger.info("Limit: #{if limit, do: "#{limit} records", else: "ALL records (millions!)"}")
    Logger.info("Batch size: #{batch_size}")
    Logger.info("")

    import_file(csv_path, limit, batch_size)
  end

  defp import_file(csv_path, limit, batch_size) do
    start_time = System.monotonic_time(:millisecond)
    imported = :counters.new(1, [])
    failed = :counters.new(1, [])

    csv_path
    |> File.stream!()
    |> CSV.parse_stream(skip_headers: true)
    |> maybe_limit(limit)
    |> Stream.map(&row_to_attrs/1)
    |> Stream.reject(&is_nil/1)
    |> Stream.chunk_every(batch_size)
    |> Enum.each(fn batch ->
      {ok_count, fail_count} = insert_batch(batch)
      :counters.add(imported, 1, ok_count)
      :counters.add(failed, 1, fail_count)

      total = :counters.get(imported, 1)
      Logger.info("✓ Imported #{total} providers (#{fail_count} failed in this batch)...")
    end)

    elapsed = System.monotonic_time(:millisecond) - start_time
    total_imported = :counters.get(imported, 1)
    total_failed = :counters.get(failed, 1)
    db_count = Repo.aggregate(Provider, :count)

    Logger.info("")
    Logger.info("=" |> String.duplicate(60))
    Logger.info("✅ Import Complete!")
    Logger.info("=" |> String.duplicate(60))
    Logger.info("Successfully imported: #{total_imported} providers")
    Logger.info("Failed: #{total_failed} providers")
    Logger.info("Total in database: #{db_count}")
    Logger.info("Time elapsed: #{format_duration(elapsed)}")
    Logger.info("=" |> String.duplicate(60))
  end

  defp maybe_limit(stream, nil), do: stream
  defp maybe_limit(stream, limit), do: Stream.take(stream, limit)

  defp insert_batch(batch) do
    results = Enum.map(batch, &insert_provider/1)

    ok_count = Enum.count(results, fn r -> match?({:ok, _}, r) end)
    fail_count = Enum.count(results, fn r -> match?({:error, _}, r) end)

    {ok_count, fail_count}
  end

  defp insert_provider(attrs) do
    %Provider{}
    |> Provider.changeset(attrs)
    |> Repo.insert(
      on_conflict: :replace_all,
      conflict_target: :npi
    )
  end

  # Map NPPES CSV columns to our provider attributes
  # Based on actual column positions from your file
  defp row_to_attrs(row) do
    # Column indices (0-based, subtract 1 from the numbered list)
    # Column 1: NPI
    npi = Enum.at(row, 0)
    # Column 2: Entity Type (1=Individual, 2=Organization)
    entity_type = Enum.at(row, 1)
    # Column 5: Organization Name
    org_name = Enum.at(row, 4)
    # Column 6: Last Name
    last_name = Enum.at(row, 5)
    # Column 7: First Name
    first_name = Enum.at(row, 6)
    # Column 48: Primary Taxonomy
    taxonomy = Enum.at(row, 47)
    # Column 35: Practice Location Phone
    phone = Enum.at(row, 34)
    # Column 29: Practice Address Line 1
    address1 = Enum.at(row, 28)
    # Column 30: Practice Address Line 2
    address2 = Enum.at(row, 29)
    # Column 31: Practice City
    city = Enum.at(row, 30)
    # Column 32: Practice State
    state = Enum.at(row, 31)
    # Column 33: Practice Zip
    zip = Enum.at(row, 32)

    # Skip if no valid NPI
    if valid_npi?(npi) do
      %{
        npi: String.trim(npi),
        name: format_name(entity_type, org_name, last_name, first_name),
        taxonomy: safe_trim(taxonomy),
        phone: safe_trim(phone),
        address: format_address(address1, address2, city, state, zip)
      }
    else
      nil
    end
  end

  defp valid_npi?(npi) when is_binary(npi) do
    String.match?(npi, ~r/^\d{10}$/)
  end

  defp valid_npi?(_), do: false

  defp format_name("1", _org, last, first) do
    # Individual provider
    last = safe_trim(last)
    first = safe_trim(first)

    cond do
      last != "" && first != "" -> "#{last}, #{first}"
      last != "" -> last
      first != "" -> first
      true -> "Unknown Individual"
    end
  end

  defp format_name("2", org, _last, _first) do
    # Organization
    org = safe_trim(org)
    if org != "", do: org, else: "Unknown Organization"
  end

  defp format_name(_, org, last, first) do
    # Fallback
    cond do
      safe_trim(org) != "" -> safe_trim(org)
      safe_trim(last) != "" -> format_name("1", nil, last, first)
      true -> "Unknown"
    end
  end

  defp format_address(addr1, addr2, city, state, zip) do
    parts =
      [
        safe_trim(addr1),
        safe_trim(addr2),
        safe_trim(city),
        safe_trim(state),
        safe_trim(zip)
      ]
      |> Enum.reject(&(&1 == ""))
      |> Enum.join(", ")

    if parts == "", do: nil, else: parts
  end

  defp safe_trim(nil), do: ""
  defp safe_trim(str) when is_binary(str), do: String.trim(str)
  defp safe_trim(_), do: ""

  defp format_duration(ms) when ms < 1000, do: "#{ms}ms"

  defp format_duration(ms) when ms < 60_000 do
    "#{Float.round(ms / 1000, 2)}s"
  end

  defp format_duration(ms) do
    minutes = div(ms, 60_000)
    seconds = rem(ms, 60_000) |> div(1000)
    "#{minutes}m #{seconds}s"
  end
end
