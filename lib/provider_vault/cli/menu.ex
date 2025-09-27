defmodule ProviderVault.CLI.Menu do
  @moduledoc false

  def print_menu do
    IO.puts("""
    Choose an option:
    1) Add provider
    2) List providers
    3) Find by NPI
    4) Edit a provider
    5) Delete a provider
    6) Search by name
    7) Import sample data
    8) Clear all records
    9) Convert Excel -> CSV
    10) Exit
    11) Fetch monthly NPPES
    """)
  end

  def prompt_choice do
    case IO.gets("\nEnter number:  ") do
      :eof ->
        :exit

      nil ->
        :exit

      input ->
        input |> String.trim() |> choice_from_string()
    end
  end

  defp choice_from_string("1"), do: :add
  defp choice_from_string("2"), do: :list
  defp choice_from_string("3"), do: :find_npi
  defp choice_from_string("4"), do: :edit
  defp choice_from_string("5"), do: :delete
  defp choice_from_string("6"), do: :search_name
  defp choice_from_string("7"), do: :import_samples
  defp choice_from_string("8"), do: :clear_all
  defp choice_from_string("9"), do: :excel_to_csv
  defp choice_from_string("10"), do: :exit
  defp choice_from_string("11"), do: :fetch_nppes
  defp choice_from_string(_), do: :invalid

  # Stub so compilation is clean; fill in later with real XLSX->CSV logic.
  def excel_to_csv do
    IO.puts("\n-- Convert Excel -> CSV -- (coming soon)")
    :ok
  end
end
