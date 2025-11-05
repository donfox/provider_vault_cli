# lib/provider_vault/cli.ex
defmodule ProviderVault.CLI do
  alias ProviderVault.Storage
  alias ProviderVault.DataSources.Orchestrator

  @moduledoc """
  Command-line interface for Provider Vault.

  Available commands:
    fetch       - Fetch provider data from all sources concurrently
    refresh     - Clear database and fetch fresh data
    add         - Add a new provider
    list        - List all providers
    search      - Search providers by name, specialty, or city
    show        - Show detailed provider information
    update      - Update provider information
    delete      - Delete a provider
    import      - Import providers from CSV
    export      - Export providers to CSV
    clear       - Clear all providers
    stats       - Show database statistics
    help        - Show this help message
  """

  def main(args) do
    # Ensure the database and table exist
    Storage.init()

    case args do
      [] ->
        show_help()

      ["help"] ->
        show_help()

      ["fetch"] ->
        handle_fetch()

      ["refresh"] ->
        handle_refresh()

      ["add" | _] ->
        handle_add(args)

      ["list" | rest] ->
        handle_list(rest)

      ["search" | rest] ->
        handle_search(rest)

      ["show", npi] ->
        handle_show(npi)

      ["update", npi | _] ->
        handle_update(npi, args)

      ["delete", npi] ->
        handle_delete(npi)

      ["import", file_path] ->
        handle_import(file_path)

      ["export", file_path] ->
        handle_export(file_path)

      ["clear"] ->
        handle_clear()

      ["stats"] ->
        handle_stats()

      _ ->
        IO.puts("Unknown command. Type 'help' for available commands.")
        show_help()
    end
  end

  # ===== HELP =====

  defp show_help do
    IO.puts("""

    Provider Vault CLI - Medical Provider Database Management

    USAGE:
      provider_vault_cli <command> [options]

    DATA FETCHING COMMANDS:
      fetch                            Fetch provider data from all sources concurrently
      refresh                          Clear database and fetch fresh data

    PROVIDER MANAGEMENT COMMANDS:
      add                              Add a new provider interactively
      list [--limit N]                 List all providers (default: 50)
      search <query>                   Search by name, specialty, or city
      show <npi>                       Show detailed provider information
      update <npi>                     Update provider information
      delete <npi>                     Delete a provider by NPI
      import <csv_file>                Import providers from CSV
      export <csv_file>                Export all providers to CSV
      clear                            Clear all providers from database
      stats                            Show database statistics
      help                             Show this help message

    EXAMPLES:
      # Fetch data from multiple sources concurrently
      provider_vault_cli fetch

      # Clear and refresh all data
      provider_vault_cli refresh

      # List providers
      provider_vault_cli list --limit 10

      # Search for providers
      provider_vault_cli search "Smith"
      provider_vault_cli search "Cardiology"

      # View provider details
      provider_vault_cli show 1234567890

    """)
  end

  # ===== FETCH =====

  defp handle_fetch do
    IO.puts("\n🚀 Fetching provider data from all sources...\n")

    case Orchestrator.fetch_and_store() do
      {:ok, stats} ->
        IO.puts("\n✓ Fetch completed successfully!\n")

        summary = Orchestrator.get_summary()
        print_fetch_summary(summary)

      {:error, reason} ->
        IO.puts("\n✗ Fetch failed: #{inspect(reason)}\n")
    end
  end

  # ===== REFRESH =====

  defp handle_refresh do
    IO.puts("\n⚠️  This will clear all existing data and fetch fresh data.")
    confirmation = prompt("Continue? (yes/no)")

    if confirmation in ["yes", "y"] do
      IO.puts("\n🔄 Refreshing data...\n")

      case Orchestrator.refresh() do
        {:ok, _stats} ->
          IO.puts("\n✓ Refresh completed successfully!\n")

        {:error, reason} ->
          IO.puts("\n✗ Refresh failed: #{inspect(reason)}\n")
      end
    else
      IO.puts("\nRefresh cancelled\n")
    end
  end

  defp print_fetch_summary(summary) do
    IO.puts("""
    Database Summary:
    ─────────────────────────────────────
    Total Providers:      #{summary.total_providers}
    Unique Specialties:   #{summary.unique_specialties}
    Unique States:        #{summary.unique_states}

    Top Specialties:
    """)

    summary.top_specialties
    |> Enum.take(3)
    |> Enum.each(fn {specialty, count} ->
      IO.puts("  • #{specialty}: #{count}")
    end)

    IO.puts("")
  end

  # ===== ADD =====

  defp handle_add(_args) do
    IO.puts("\n=== Add New Provider ===\n")

    attrs = %{
      npi: prompt("NPI (10 digits)"),
      first_name: prompt("First Name"),
      last_name: prompt("Last Name"),
      credential: prompt("Credential (e.g., MD, DO, NP)"),
      specialty: prompt("Specialty"),
      address: prompt("Address"),
      city: prompt("City"),
      state: prompt("State (2 letters)"),
      zip: prompt("ZIP Code"),
      phone: prompt("Phone")
    }

    case Storage.insert_provider(attrs) do
      {:ok, provider} ->
        IO.puts("\n✓ Provider added successfully!")
        print_provider(provider)

      {:error, changeset} ->
        IO.puts("\n✗ Failed to add provider:")
        print_errors(changeset)
    end
  end

  # ===== LIST =====

  defp handle_list(args) do
    limit = parse_limit(args)

    case Storage.list_providers(limit) do
      [] ->
        IO.puts("\nNo providers found in database.")
        IO.puts("Use 'fetch' to retrieve provider data or 'add' to add manually.\n")

      providers ->
        IO.puts("\n=== Providers (showing #{length(providers)}) ===\n")
        print_providers_table(providers)
    end
  end

  # ===== SEARCH =====

  defp handle_search([]) do
    IO.puts("Error: Search query required")
    IO.puts("Usage: provider_vault_cli search <query>")
  end

  defp handle_search(query_parts) do
    query = Enum.join(query_parts, " ")

    IO.puts("\nSearching for: '#{query}'...\n")

    providers = Storage.search_providers(query)

    case providers do
      [] ->
        IO.puts("No providers found matching '#{query}'")

      results ->
        IO.puts("=== Found #{length(results)} provider(s) ===\n")
        print_providers_table(results)
    end
  end

  # ===== SHOW =====

  defp handle_show(npi) do
    case Storage.get_provider(npi) do
      nil ->
        IO.puts("\n✗ Provider with NPI #{npi} not found\n")

      provider ->
        IO.puts("\n=== Provider Details ===\n")
        print_provider_detailed(provider)
    end
  end

  # ===== UPDATE =====

  defp handle_update(npi, _args) do
    case Storage.get_provider(npi) do
      nil ->
        IO.puts("\n✗ Provider with NPI #{npi} not found\n")

      provider ->
        IO.puts("\n=== Update Provider (NPI: #{npi}) ===")
        IO.puts("Press Enter to keep current value\n")

        attrs = %{
          first_name: prompt_with_default("First Name", provider.first_name),
          last_name: prompt_with_default("Last Name", provider.last_name),
          credential: prompt_with_default("Credential", provider.credential),
          specialty: prompt_with_default("Specialty", provider.specialty),
          address: prompt_with_default("Address", provider.address),
          city: prompt_with_default("City", provider.city),
          state: prompt_with_default("State", provider.state),
          zip: prompt_with_default("ZIP", provider.zip),
          phone: prompt_with_default("Phone", provider.phone)
        }

        # Remove empty values
        attrs = Enum.reject(attrs, fn {_k, v} -> v == "" end) |> Map.new()

        case Storage.update_provider(provider, attrs) do
          {:ok, updated} ->
            IO.puts("\n✓ Provider updated successfully!")
            print_provider(updated)

          {:error, changeset} ->
            IO.puts("\n✗ Failed to update provider:")
            print_errors(changeset)
        end
    end
  end

  # ===== DELETE =====

  defp handle_delete(npi) do
    case Storage.get_provider(npi) do
      nil ->
        IO.puts("\n✗ Provider with NPI #{npi} not found\n")

      provider ->
        print_provider(provider)

        confirmation = prompt("\nAre you sure you want to delete this provider? (yes/no)")

        if confirmation in ["yes", "y"] do
          case Storage.delete_provider(provider) do
            {:ok, _} ->
              IO.puts("\n✓ Provider deleted successfully\n")

            {:error, reason} ->
              IO.puts("\n✗ Failed to delete provider: #{inspect(reason)}\n")
          end
        else
          IO.puts("\nDeletion cancelled\n")
        end
    end
  end

  # ===== IMPORT =====

  defp handle_import(file_path) do
    if File.exists?(file_path) do
      IO.puts("\nImporting from #{file_path}...\n")

      case Storage.import_from_csv(file_path) do
        {:ok, count} ->
          IO.puts("✓ Successfully imported #{count} providers\n")

        {:error, reason} ->
          IO.puts("✗ Import failed: #{reason}\n")
      end
    else
      IO.puts("\n✗ File not found: #{file_path}\n")
    end
  end

  # ===== EXPORT =====

  defp handle_export(file_path) do
    IO.puts("\nExporting to #{file_path}...\n")

    case Storage.export_to_csv(file_path) do
      {:ok, count} ->
        IO.puts("✓ Successfully exported #{count} providers to #{file_path}\n")

      {:error, reason} ->
        IO.puts("✗ Export failed: #{reason}\n")
    end
  end

  # ===== CLEAR =====

  defp handle_clear do
    confirmation = prompt("\n⚠️  This will delete ALL providers. Are you sure? (yes/no)")

    if confirmation in ["yes", "y"] do
      case Storage.clear_all() do
        {:ok, :cleared} ->
          IO.puts("\n✓ All providers cleared successfully\n")

        {:error, reason} ->
          IO.puts("\n✗ Failed to clear providers: #{inspect(reason)}\n")
      end
    else
      IO.puts("\nOperation cancelled\n")
    end
  end

  # ===== STATS =====

  defp handle_stats do
    stats = Storage.get_stats()

    IO.puts("""

    === Database Statistics ===

    Total Providers:     #{stats.total_count}
    Unique Specialties:  #{stats.specialty_count}
    Unique States:       #{stats.state_count}

    Top 5 Specialties:
    """)

    Enum.each(stats.top_specialties, fn {specialty, count} ->
      IO.puts("  #{String.pad_trailing(specialty || "Unknown", 30)} #{count}")
    end)

    IO.puts("\nTop 5 States:")

    Enum.each(stats.top_states, fn {state, count} ->
      IO.puts("  #{String.pad_trailing(state || "Unknown", 30)} #{count}")
    end)

    IO.puts("")
  end

  # ===== HELPER FUNCTIONS =====

  defp prompt(message) do
    IO.gets("#{message}: ") |> String.trim()
  end

  defp prompt_with_default(message, default) do
    input = IO.gets("#{message} [#{default}]: ") |> String.trim()
    if input == "", do: default, else: input
  end

  defp parse_limit(args) do
    case Enum.find_index(args, &(&1 == "--limit")) do
      nil ->
        50

      index ->
        args
        |> Enum.at(index + 1, "50")
        |> String.to_integer()
    end
  end

  defp print_provider(provider) do
    IO.puts("""
      NPI:        #{provider.npi}
      Name:       #{provider.first_name} #{provider.last_name}, #{provider.credential}
      Specialty:  #{provider.specialty}
      Location:   #{provider.city}, #{provider.state} #{provider.zip}
      Phone:      #{provider.phone}
    """)
  end

  defp print_provider_detailed(provider) do
    IO.puts("""
      NPI:           #{provider.npi}
      Name:          #{provider.first_name} #{provider.last_name}
      Credential:    #{provider.credential}
      Specialty:     #{provider.specialty}
      Address:       #{provider.address}
      City:          #{provider.city}
      State:         #{provider.state}
      ZIP:           #{provider.zip}
      Phone:         #{provider.phone}
      Inserted:      #{provider.inserted_at}
      Last Updated:  #{provider.updated_at}
    """)
  end

  defp print_providers_table(providers) do
    # Header
    IO.puts(
      String.pad_trailing("NPI", 12) <>
        String.pad_trailing("Name", 30) <>
        String.pad_trailing("Specialty", 25) <>
        "Location"
    )

    IO.puts(String.duplicate("-", 90))

    # Rows
    Enum.each(providers, fn p ->
      name = "#{p.first_name} #{p.last_name}, #{p.credential}"
      location = "#{p.city}, #{p.state}"

      IO.puts(
        String.pad_trailing(p.npi, 12) <>
          String.pad_trailing(String.slice(name, 0..28), 30) <>
          String.pad_trailing(String.slice(p.specialty || "N/A", 0..23), 25) <>
          location
      )
    end)

    IO.puts("")
  end

  defp print_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
    |> Enum.each(fn {field, errors} ->
      IO.puts("  #{field}: #{Enum.join(errors, ", ")}")
    end)
  end
end
