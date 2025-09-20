defmodule ProviderVault.CLI.Menu do
  alias Mix.Shell.IO, as: Shell
  alias ProviderVault.Excel.Convert, as: Convert

  @choices [
    {:add, "Add provider"},
    {:list, "List providers"},
    {:find_npi, "Find by NPI"},
    {:edit, "Edit a provider"},
    {:delete, "Delete a provider"},
    {:search_name, "Search by name"},
    {:import_samples, "Import sample data"},
    {:clear_all, "Clear all records"},
    {:excel_to_csv, "Convert Excel -> CSV"},
    {:exit, "Exit"}
  ]

  def print_menu do
    header = "Choose an option:\n"

    body =
      @choices
      |> Enum.with_index(1)
      |> Enum.map(fn {{_action, label}, i} -> "#{i}) #{label}" end)
      |> Enum.join("\n")

    Shell.info(header <> body <> "\n")
  end

  def prompt_choice do
    case safe_prompt("Enter number: ") do
      :eof ->
        :exit

      input ->
        trimmed = String.trim(input)

        # allow 'q' to quit quickly
        if trimmed in ["q", "Q"] do
          :exit
        else
          with {n, ""} <- Integer.parse(trimmed),
               true <- n >= 1 and n <= length(@choices) do
            @choices |> Enum.at(n - 1) |> elem(0)
          else
            _ ->
              Shell.error("Invalid choice.")
              prompt_choice()
          end
        end
    end
  end

  defp safe_prompt(msg) do
    case IO.gets(msg) do
      :eof -> :eof
      nil -> :eof
      bin -> bin
    end
  end

  @doc """
  Prompt for a file or directory and convert Excel (.xlsx) to CSV.
  Output defaults to ./data unless overridden.
  """
  def excel_to_csv do
    Shell.cmd("clear")
    Shell.info("== Excel -> CSV ==")

    path =
      Shell.prompt("Path to .xlsx file OR directory: ")
      |> String.trim()

    if path == "" do
      Shell.error("No path provided.")
      :noop
    else
      sheet =
        Shell.prompt("Sheet index (default 0): ")
        |> String.trim()
        |> parse_int_default(0)

      out_dir =
        Shell.prompt("Output directory (default ./data): ")
        |> String.trim()
        |> default_if_blank("data")
        |> Path.expand(File.cwd!())

      opts = [sheet: sheet, out_dir: out_dir]

      if File.dir?(path) do
        results = Convert.convert_all(path, opts)

        Shell.info("\nResults:")

        Enum.each(results, fn {p, res} ->
          case res do
            {:ok, out} -> Shell.info("OK   #{p}  ->  #{out}")
            {:error, reason} -> Shell.error("ERR  #{p}  ->  #{inspect(reason)}")
          end
        end)
      else
        case Convert.convert_file(path, opts) do
          {:ok, out} -> Shell.info("\nOK   #{path}  ->  #{out}")
          {:error, reason} -> Shell.error("\nERR  #{path}  ->  #{inspect(reason)}")
        end
      end

      Shell.prompt("\nPress Enter to return to menu")
    end
  end

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
