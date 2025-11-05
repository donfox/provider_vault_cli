defmodule ProviderVault.Storage do
  @moduledoc """
  Database storage for provider records using Ecto/PostgreSQL.

  This module provides the data access layer for medical provider information.
  All data is stored in PostgreSQL and accessed via Ecto queries.

  ## Usage

      Storage.init()
      Storage.insert_provider(%{npi: "1234567890", first_name: "John", ...})
      Storage.list_providers(50)
      Storage.search_providers("Smith")
      Storage.get_provider("1234567890")
      Storage.import_from_csv("providers.csv")
  """

  import Ecto.Query
  alias ProviderVault.Repo
  alias ProviderVault.Provider

  # =============================================================================
  # PUBLIC API - Database Operations
  # =============================================================================

  @doc """
  Initialize the storage system.
  Called when the CLI starts to ensure database is ready.
  """
  def init do
    # Database initialization is handled by migrations
    # This is a no-op but kept for CLI compatibility
    :ok
  end

  @doc """
  Insert a new provider into the database.
  Returns {:ok, provider} or {:error, changeset}.
  """
  def insert_provider(attrs) do
    %Provider{}
    |> Provider.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  List providers with optional limit.
  Returns a list of provider structs.
  """
  def list_providers(limit \\ 50) do
    Provider
    |> limit(^limit)
    |> order_by([p], desc: p.inserted_at)
    |> Repo.all()
  end

  @doc """
  Search providers by name, specialty, city, or state.
  Returns a list of matching providers.
  """
  def search_providers(query) do
    search_term = "%#{query}%"

    Provider
    |> where(
      [p],
      ilike(p.first_name, ^search_term) or
        ilike(p.last_name, ^search_term) or
        ilike(p.specialty, ^search_term) or
        ilike(p.city, ^search_term) or
        ilike(p.state, ^search_term)
    )
    |> order_by([p], [p.last_name, p.first_name])
    |> Repo.all()
  end

  @doc """
  Get a single provider by NPI.
  Returns provider struct or nil.
  """
  def get_provider(npi) do
    Repo.get_by(Provider, npi: npi)
  end

  @doc """
  Update a provider with new attributes.
  Returns {:ok, provider} or {:error, changeset}.
  """
  def update_provider(provider, attrs) do
    provider
    |> Provider.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Delete a provider from the database.
  Returns {:ok, provider} or {:error, changeset}.
  """
  def delete_provider(provider) do
    Repo.delete(provider)
  end

  @doc """
  Clear all providers from the database.
  Returns {:ok, :cleared} or {:error, reason}.
  """
  def clear_all do
    try do
      Repo.delete_all(Provider)
      {:ok, :cleared}
    rescue
      e -> {:error, e}
    end
  end

  @doc """
  Get database statistics.
  Returns a map with counts and top categories.
  """
  def get_stats do
    total_count = Repo.aggregate(Provider, :count)

    specialty_count =
      Provider
      |> select([p], p.specialty)
      |> distinct(true)
      |> Repo.aggregate(:count)

    state_count =
      Provider
      |> select([p], p.state)
      |> distinct(true)
      |> Repo.aggregate(:count)

    top_specialties =
      Provider
      |> group_by([p], p.specialty)
      |> select([p], {p.specialty, count(p.id)})
      |> order_by([p], desc: count(p.id))
      |> limit(5)
      |> Repo.all()

    top_states =
      Provider
      |> group_by([p], p.state)
      |> select([p], {p.state, count(p.id)})
      |> order_by([p], desc: count(p.id))
      |> limit(5)
      |> Repo.all()

    %{
      total_count: total_count,
      specialty_count: specialty_count,
      state_count: state_count,
      top_specialties: top_specialties,
      top_states: top_states
    }
  end

  @doc """
  Import providers from a CSV file.
  Expected columns: npi, first_name, last_name, credential, specialty,
                    address, city, state, zip, phone
  Returns {:ok, count} or {:error, reason}.
  """
  def import_from_csv(file_path) do
    count =
      file_path
      |> File.stream!()
      # Skip header
      |> Stream.drop(1)
      |> Stream.map(&String.trim/1)
      |> Stream.reject(&(&1 == ""))
      |> Stream.map(&parse_csv_line/1)
      |> Enum.reduce(0, fn row_data, acc ->
        attrs = %{
          npi: Enum.at(row_data, 0),
          first_name: Enum.at(row_data, 1),
          last_name: Enum.at(row_data, 2),
          credential: Enum.at(row_data, 3),
          specialty: Enum.at(row_data, 4),
          address: Enum.at(row_data, 5),
          city: Enum.at(row_data, 6),
          state: Enum.at(row_data, 7),
          zip: Enum.at(row_data, 8),
          phone: Enum.at(row_data, 9)
        }

        case insert_provider(attrs) do
          {:ok, _} -> acc + 1
          # Skip invalid rows
          {:error, _} -> acc
        end
      end)

    {:ok, count}
  rescue
    e -> {:error, Exception.message(e)}
  end

  @doc """
  Export all providers to a CSV file.
  Returns {:ok, count} or {:error, reason}.
  """
  def export_to_csv(file_path) do
    providers = Repo.all(Provider)

    rows = [
      [
        "npi",
        "first_name",
        "last_name",
        "credential",
        "specialty",
        "address",
        "city",
        "state",
        "zip",
        "phone"
      ]
      | Enum.map(providers, fn p ->
          [
            p.npi,
            p.first_name,
            p.last_name,
            p.credential,
            p.specialty,
            p.address,
            p.city,
            p.state,
            p.zip,
            p.phone
          ]
        end)
    ]

    csv_content =
      rows
      |> Enum.map(fn row ->
        row
        |> Enum.map(&escape_csv_field/1)
        |> Enum.join(",")
      end)
      |> Enum.join("\n")

    case File.write(file_path, csv_content) do
      :ok -> {:ok, length(providers)}
      error -> error
    end
  end

  # =============================================================================
  # PRIVATE HELPERS
  # =============================================================================

  # Simple CSV parser for import
  defp parse_csv_line(line) do
    line
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(&remove_quotes/1)
  end

  defp remove_quotes(str) do
    str
    |> String.trim()
    |> String.trim("\"")
  end

  # Simple CSV escaping for export
  defp escape_csv_field(nil), do: ""

  defp escape_csv_field(value) when is_binary(value) do
    if String.contains?(value, [",", "\"", "\n"]) do
      escaped = String.replace(value, "\"", "\"\"")
      "\"#{escaped}\""
    else
      value
    end
  end

  defp escape_csv_field(value), do: to_string(value)

  # =============================================================================
  # OLD CSV-BASED FUNCTIONS (Commented out - kept for reference)
  # =============================================================================

  # The following functions were used for CSV file storage.
  # They are kept here commented out in case you need to reference them,
  # but the system now uses PostgreSQL/Ecto exclusively.

  # defmodule Provider do
  #   @enforce_keys [:npi, :name]
  #   defstruct [:npi, :name, :taxonomy, :phone, :address]
  # end

  # def add_provider(npi, name, taxonomy, phone, address) do
  #   # Old CSV implementation
  # end

  # def all do
  #   # Old CSV implementation
  # end

  # def find_by_npi(npi) do
  #   # Old CSV implementation
  # end

  # def edit_provider(npi, attrs) do
  #   # Old CSV implementation
  # end

  # def search_by_name(term) do
  #   # Old CSV implementation
  # end
end
