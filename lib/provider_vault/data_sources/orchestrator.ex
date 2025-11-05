defmodule ProviderVault.DataSources.Orchestrator do
  @moduledoc """
  Orchestrates concurrent data fetching from multiple provider sources.

  This module demonstrates Elixir's concurrency by fetching data from
  multiple sources simultaneously using Task.async_stream.

  ## Usage

      # Fetch from all sources concurrently
      {:ok, results} = Orchestrator.fetch_all()

      # Fetch and store in database
      {:ok, stats} = Orchestrator.fetch_and_store()
  """

  require Logger
  alias ProviderVault.Storage
  alias ProviderVault.DataSources.{NPPESFetcher, MockProviderA, MockProviderB, MockProviderC}

  @sources [
    {NPPESFetcher, "NPPES"},
    {MockProviderA, "Mock-PrimaryCare"},
    {MockProviderB, "Mock-SurgicalSpec"},
    {MockProviderC, "Mock-MentalHealth"}
  ]

  @doc """
  Fetch data from all sources concurrently.
  Returns {:ok, results} where results is a list of {:ok, providers} or {:error, reason}.
  """
  def fetch_all do
    Logger.info("=== Starting concurrent fetch from #{length(@sources)} sources ===")
    start_time = System.monotonic_time(:millisecond)

    results =
      @sources
      |> Task.async_stream(
        fn {module, name} ->
          Logger.debug("Starting fetch: #{name}")
          result = module.fetch()
          Logger.debug("Completed fetch: #{name}")
          {name, result}
        end,
        max_concurrency: 4,
        timeout: 30_000,
        on_timeout: :kill_task
      )
      |> Enum.map(fn
        {:ok, result} -> result
        {:exit, reason} -> {:error, reason}
      end)

    elapsed = System.monotonic_time(:millisecond) - start_time
    Logger.info("=== Completed all fetches in #{elapsed}ms ===")

    {:ok, results}
  end

  @doc """
  Fetch data from all sources and store in the database.
  Returns {:ok, stats} with statistics about the operation.
  """
  def fetch_and_store do
    Logger.info("=== Fetching and storing provider data ===")
    overall_start = System.monotonic_time(:millisecond)

    # Fetch all data concurrently
    {:ok, results} = fetch_all()

    # Process results and store in database
    stats = process_and_store_results(results)

    elapsed = System.monotonic_time(:millisecond) - overall_start
    Logger.info("=== Total operation time: #{elapsed}ms ===")

    {:ok, Map.put(stats, :total_time_ms, elapsed)}
  end

  defp process_and_store_results(results) do
    initial_stats = %{
      sources_processed: 0,
      sources_failed: 0,
      providers_fetched: 0,
      providers_stored: 0,
      providers_failed: 0,
      by_source: %{}
    }

    results
    |> Enum.reduce(initial_stats, fn result, acc ->
      case result do
        {source_name, {:ok, providers}} ->
          Logger.info("[#{source_name}] Processing #{length(providers)} providers")

          source_stats = store_providers(providers, source_name)

          acc
          |> Map.update!(:sources_processed, &(&1 + 1))
          |> Map.update!(:providers_fetched, &(&1 + length(providers)))
          |> Map.update!(:providers_stored, &(&1 + source_stats.stored))
          |> Map.update!(:providers_failed, &(&1 + source_stats.failed))
          |> put_in([:by_source, source_name], source_stats)

        {source_name, {:error, reason}} ->
          Logger.error("[#{source_name}] Fetch failed: #{inspect(reason)}")

          acc
          |> Map.update!(:sources_failed, &(&1 + 1))
          |> put_in([:by_source, source_name], %{error: reason})

        _ ->
          acc
      end
    end)
  end

  defp store_providers(providers, source_name) do
    results =
      providers
      |> Enum.map(fn provider_data ->
        case Storage.insert_provider(provider_data) do
          {:ok, _provider} ->
            :ok

          {:error, changeset} ->
            Logger.debug(
              "[#{source_name}] Failed to store provider: #{inspect(changeset.errors)}"
            )

            :error
        end
      end)

    stored = Enum.count(results, &(&1 == :ok))
    failed = Enum.count(results, &(&1 == :error))

    Logger.info("[#{source_name}] Stored: #{stored}, Failed: #{failed}")

    %{
      total: length(providers),
      stored: stored,
      failed: failed
    }
  end

  @doc """
  Get a summary of the last fetch operation.
  """
  def get_summary do
    db_stats = Storage.get_stats()

    %{
      total_providers: db_stats.total_count,
      unique_specialties: db_stats.specialty_count,
      unique_states: db_stats.state_count,
      top_specialties: db_stats.top_specialties,
      top_states: db_stats.top_states
    }
  end

  @doc """
  Clear all provider data from the database.
  Useful before running a fresh fetch.
  """
  def clear_all do
    case Storage.clear_all() do
      {:ok, :cleared} ->
        Logger.info("Database cleared successfully")
        {:ok, :cleared}

      {:error, reason} ->
        Logger.error("Failed to clear database: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Run a complete refresh: clear database and fetch new data.
  """
  def refresh do
    Logger.info("=== Starting full refresh ===")

    with {:ok, :cleared} <- clear_all(),
         {:ok, stats} <- fetch_and_store() do
      Logger.info("=== Refresh complete ===")
      print_summary(stats)
      {:ok, stats}
    else
      error -> error
    end
  end

  defp print_summary(stats) do
    IO.puts("""

    ╔═══════════════════════════════════════════════════╗
    ║         DATA FETCH SUMMARY                        ║
    ╚═══════════════════════════════════════════════════╝

    Sources Processed:     #{stats.sources_processed}/#{length(@sources)}
    Sources Failed:        #{stats.sources_failed}

    Providers Fetched:     #{stats.providers_fetched}
    Providers Stored:      #{stats.providers_stored}
    Providers Failed:      #{stats.providers_failed}

    Total Time:            #{stats.total_time_ms}ms

    By Source:
    """)

    Enum.each(stats.by_source, fn {source, source_stats} ->
      case source_stats do
        %{error: error} ->
          IO.puts("  #{String.pad_trailing(source, 20)} ✗ ERROR: #{inspect(error)}")

        %{stored: stored, failed: failed} ->
          IO.puts("  #{String.pad_trailing(source, 20)} ✓ Stored: #{stored}, Failed: #{failed}")
      end
    end)

    IO.puts("")
  end
end
