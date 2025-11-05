# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ProviderVault CLI (v1.7) is a lightweight Elixir CLI for managing healthcare provider records from NPPES (National Plan & Provider Enumeration System). It supports both CSV-based storage and PostgreSQL database operations, with features for importing massive NPPES datasets (7+ million records), interactive menu operations, and automatic fetching of monthly NPPES data releases.

## Development Commands

### Build and Run

```bash
# Build the escript (standalone executable)
mix do clean, compile, escript.build
./provider_vault_cli

# Or run via Mix
mix provider.start

# Run with flags
./provider_vault_cli --help
./provider_vault_cli --version
```

### Testing

```bash
# Run all tests
mix test

# Run a specific test file
mix test test/storage_test.exs

# Run a specific test
mix test test/storage_test.exs:10
```

### Code Quality

```bash
# Format code
mix format

# Check formatting without changes
mix format --check-formatted

# Run full check (format + compile + test)
mix check

# Initial setup
mix setup
```

### NPPES Data Import

```bash
# Import first 30 records (testing)
mix nppes.import priv/data/npidata_pfile_20050523-20251012.csv --limit 30

# Import first 1000 records
mix nppes.import priv/data/npidata_pfile_20050523-20251012.csv --limit 1000

# Import all records (WARNING: 7+ million records, takes hours!)
mix nppes.import priv/data/npidata_pfile_20050523-20251012.csv

# Custom batch size
mix nppes.import <path> --limit 1000 --batch 500
```

### Fetch NPPES Data

```bash
# Fetch current month's data automatically
mix nppes.fetch

# Fetch specific URL
mix nppes.fetch --url https://example.com/data.zip --to priv/data
```

## Architecture

### Dual Storage System

The application implements **two parallel storage backends** that do not currently interact:

1. **CSV Storage** (`ProviderVault.Storage`): Used by the interactive CLI menu
   - Location: `priv/data/providers.csv` (configurable via `PROVIDER_VAULT_DATA_DIR`)
   - Columns: `npi, name, taxonomy, phone, address`
   - Features: NPI deduplication, legacy file support, map-based API for CLI
   - Used by: `ProviderVault.CLI` module for all 8 menu options

2. **PostgreSQL Storage** (`ProviderVault.Repo` + `ProviderVault.Provider`): Used by Mix tasks
   - Ecto-based with `providers` table
   - Schema: `npi` (string, unique), `name`, `taxonomy`, `phone`, `address`, `timestamps`
   - Used by: `mix nppes.import` for bulk data imports
   - Database config: `config/config.exs` (username: "donfox1", database: "provider_vault_cli_repo")

**Important**: When modifying storage logic, determine which backend the change affects. The CLI menu operations work exclusively with CSV files, while the import task works exclusively with PostgreSQL.

### Application Structure

- **`ProviderVault.MixRunner`**: Main entry point for escript builds
- **`ProviderVault.CLI`**: Interactive menu system with 9 operations (add, list, find, edit, delete, search, clear, stats, fetch NPPES data)
- **`ProviderVault.Storage`**: CSV-backed storage with dual API (maps for CLI, structs for tests)
- **`ProviderVault.Provider`**: Ecto schema for PostgreSQL with changeset validation
- **`ProviderVault.Repo`**: Ecto repository using Postgres adapter
- **`ProviderVault.NppesFetcher`**: HTTP client for downloading NPPES monthly data releases
- **`ProviderVault.NPI`**: NPI validation utilities
- **`ProviderVault.Validators`**: General validation helpers

### Mix Tasks

Three custom Mix tasks in `lib/mix/tasks/`:

- **`mix provider.start`**: Launches the interactive CLI (alias for `ProviderVault.CLI.main/1`)
- **`mix nppes.fetch`**: Downloads NPPES data releases from CMS website
- **`mix nppes.import`**: Imports NPPES CSV data into PostgreSQL (batched inserts with progress tracking)

### CSV Parsing

The application uses `NimbleCSV.RFC4180` for CSV operations:
- Storage module handles BOM stripping and legacy file format support
- Custom CSV parser in `Storage` module for handling quoted fields
- NPPES import maps 330+ column files to 5-column provider schema (see column indices in `nppes.import.ex:120-145`)

### Configuration

- **Database**: `config/config.exs` sets Postgres connection params
- **Environment**: `config/dev.exs`, `config/test.exs` for environment-specific settings
- **Data Directory**: Override with `PROVIDER_VAULT_DATA_DIR` environment variable

## Common Development Patterns

### Adding a New CLI Menu Option

1. Add menu item to `print_menu/0` in `lib/provider_vault/cli.ex`
2. Update `read_choice/0` to accept new number
3. Implement dispatch handler in `dispatch/1`
4. Add corresponding function to `ProviderVault.Storage` if needed
5. Use `safe_call/2` wrapper for error handling

### Adding a New Storage Operation

For CSV operations, add both:
- Map-based function for CLI usage (e.g., `add_provider/5`)
- Struct-based function for test usage if needed (e.g., `append_csv/2`)

### Working with NPPES Data

NPPES CSV files contain 330+ columns. The critical column mappings are:
- Column 1 (index 0): NPI (10 digits)
- Column 2 (index 1): Entity Type (1=Individual, 2=Organization)
- Column 5 (index 4): Organization Name
- Columns 6-7 (indices 5-6): Last Name, First Name
- Column 48 (index 47): Primary Taxonomy
- Column 35 (index 34): Phone
- Columns 29-33 (indices 28-32): Address components

When modifying the import logic, refer to the official NPPES data dictionary.

## Testing

- Use `test/fixtures/` for test data files
- Storage tests use temporary CSV files
- Test helper is minimal (`test/test_helper.exs` just starts ExUnit)
- Smoke test (`test/smoke_test.exs`) provides basic sanity check

## Notable Implementation Details

- **Safe CLI execution**: All CLI storage calls wrapped in `safe_call/2` with fallback handling for missing implementations
- **NPI deduplication**: CSV storage automatically dedupes by NPI (last write wins)
- **Batch processing**: Import task uses batched inserts (default 1000) with atomic counter tracking
- **Error resilience**: Import continues on individual record failures, reports success/failure counts
- **Legacy support**: Handles old `provders.csv` filename (typo in original version)
