defmodule ProviderVault.CLI.Menu do
  alias Mix.Shell.IO, as: Shell
  alias ProviderVault.Excel.Convert

  @menu """
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
  """

  # --- Menu display ------------------------------------------------------------
  def print_menu, do: Shell.info(@menu)

  # Map numeric input to atoms your Main expects
  def prompt_choice do
    case Shell.prompt("Enter number: ") |> to_string() |> String.trim() do
      "1" -> :add
      "2" -> :list
      "3" -> :find_npi
      "4" -> :edit
      "5" -> :delete
      "6" -> :search_name
      "7" -> :import_samples
      "8" -> :clear_all
      "9" -> :excel_to_csv
      "10" -> :exit
      "11" -> :fetch_nppes
      "q" -> :exit
      "Q" -> :exit
      _ -> :invalid
    end
  end

  # --- Excel → CSV action (called by Main) ------------------------------------
  # Uses 1-based sheet index (default 1).
  def excel_to_csv do
    Shell.info("\n-- Convert Excel -> CSV --")

    xlsx_path =
      Shell.prompt("Path to .xlsx file OR directory: ")
      |> to_string()
      |> String.trim()

    if xlsx_path == "" do
      Shell.error("No path provided.")
      :noop
    else
      sheet =
        Shell.prompt("Sheet number (1-based, default 1): ")
        |> to_string()
        |> String.trim()
        |> parse_int_default(1)

      out_dir =
        Shell.prompt("Output directory (default ./data): ")
        |> to_string()
        |> String.trim()
        |> default_if_blank("data")
        |> Path.expand(File.cwd!())

      opts = [sheet: sheet, out_dir: out_dir]

      cond do
        File.dir?(xlsx_path) and function_exported?(Convert, :convert_all, 2) ->
          results = Convert.convert_all(xlsx_path, opts)
          Shell.info("\nResults:")

          Enum.each(results, fn {p, res} ->
            case res do
              {:ok, out} -> Shell.info("OK   #{p} -> #{out}")
              {:error, reason} -> Shell.error("ERR  #{p} -> #{inspect(reason)}")
            end
          end)

        File.dir?(xlsx_path) ->
          Shell.error("Directory given, but Convert.convert_all/2 not available.")

        true ->
          case Convert.convert_file(xlsx_path, opts) do
            {:ok, out} -> Shell.info("\nOK   #{xlsx_path} -> #{out}")
            {:error, reason} -> Shell.error("\nERR  #{xlsx_path} -> #{inspect(reason)}")
          end
      end

      _ = Shell.prompt("\nPress Enter to return to menu")
    end
  end

  # --- Helpers ----------------------------------------------------------------
  defp parse_int_default("", default), do: default

  defp parse_int_default(str, default) do
    case Integer.parse(str) do
      {n, ""} -> n
      _ -> default
    end
  end

  defp default_if_blank("", d), do: d
  defp default_if_blank(s, _), do: s
end
