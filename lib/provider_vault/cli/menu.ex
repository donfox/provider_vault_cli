defmodule ProviderVault.CLI.Menu do
  @moduledoc """
  Interactive menu & input handling.
  """

  @compile {:no_warn_undefined, ProviderVault.CSV}
  @compile {:no_warn_undefined, ProviderVault.Excel.Convert}
  @compile {:no_warn_undefined, ProviderVault.Ingestion.NppesFetcher}

  @spec main() :: :ok
  def main, do: loop()

  defp loop do
    print_menu()
    read_choice()
  end

  defp print_menu do
    IO.puts("""
    == Provider Vault CLI ==
    Manage simple medical provider records (CSV-backed).
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

  defp read_choice do
    case prompt("\nEnter number: ") do
      :eof -> IO.puts("\nGoodbye."); :ok
      "10" -> IO.puts("Goodbye!"); :ok
      choice when choice in ~w(1 2 3 4 5 6 7 8 9 11) ->
        dispatch(choice)
      _ ->
        IO.puts("Invalid choice (try 1–11).")
        read_choice()
    end
  end

  # --- Dispatch ---

  defp dispatch("1") do
    last  = prompt("Last name: ")
    first = prompt("First name: ")
    npi   = prompt("NPI (10 digits): ")

    safe_call(fn -> ProviderVault.CSV.add_provider(npi, last, first) end,
      fallback: fn -> IO.puts("Add not implemented yet."); :ok end
    )
    loop()
  end

  defp dispatch("2") do
    safe_call(fn -> ProviderVault.CSV.list_providers() end,
      fallback: fn -> IO.puts("List not implemented yet."); :ok end
    )
    loop()
  end

  defp dispatch("3") do
    npi = prompt("NPI: ")
    safe_call(fn -> ProviderVault.CSV.find_by_npi(npi) end,
      fallback: fn -> IO.puts("Find by NPI not implemented yet."); :ok end
    )
    loop()
  end

  defp dispatch("4") do
    npi   = prompt("NPI to edit: ")
    last  = prompt("New Last (blank to skip): ")
    first = prompt("New First (blank to skip): ")
    safe_call(fn -> ProviderVault.CSV.edit_provider(npi, last, first) end,
      fallback: fn -> IO.puts("Edit not implemented yet."); :ok end
    )
    loop()
  end

  defp dispatch("5") do
    npi = prompt("NPI to delete: ")
    safe_call(fn -> ProviderVault.CSV.delete_provider(npi) end,
      fallback: fn -> IO.puts("Delete not implemented yet."); :ok end
    )
    loop()
  end

  defp dispatch("6") do
    name = prompt("Search name (partial): ")
    safe_call(fn -> ProviderVault.CSV.search_by_name(name) end,
      fallback: fn -> IO.puts("Search not implemented yet."); :ok end
    )
    loop()
  end

  defp dispatch("7") do
    safe_call(fn -> ProviderVault.CSV.import_sample_data() end,
      fallback: fn -> IO.puts("Import sample data not implemented yet."); :ok end
    )
    loop()
  end

  defp dispatch("8") do
    confirm = prompt("Type 'YES' to clear all records: ")
    if confirm == "YES" do
      safe_call(fn -> ProviderVault.CSV.clear_all() end,
        fallback: fn -> IO.puts("Clear all not implemented yet."); :ok end
      )
    else
      IO.puts("Cancelled.")
    end
    loop()
  end

  defp dispatch("9") do
    xlsx     = prompt("Path to .xlsx: ")
    sheet_in = prompt("Sheet (index starting at 1 OR name): ")
    opts =
      case Integer.parse(sheet_in) do
        {idx, ""} when idx > 0 -> [sheet: idx]
        _ -> [sheet: sheet_in]
      end

    safe_call(fn -> ProviderVault.Excel.Convert.convert_file(xlsx, opts) end,
      fallback: fn -> IO.puts("Excel -> CSV not implemented yet."); :ok end
    )
    loop()
  end

  defp dispatch("11") do
    url_input = prompt("NPPES monthly ZIP URL (blank to use env NPPES_URL): ")
    dest      = prompt("Destination dir (default priv/data): ")
    dest_dir  = if dest == "", do: "priv/data", else: dest
    url       = if url_input == "", do: System.get_env("NPPES_URL") || "", else: url_input

    if url == "" do
      IO.puts("No URL provided and NPPES_URL is not set. Aborting.")
    else
      safe_call(
        fn ->
          out_path = ProviderVault.Ingestion.NppesFetcher.fetch!(url, to: dest_dir)
          IO.puts("Downloaded to: #{out_path}")
          {:ok, out_path}
        end,
        fallback: fn -> IO.puts("NPPES fetcher not implemented yet."); :ok end
      )
    end
    loop()
  end

  defp dispatch(_other) do
    IO.puts("Invalid choice")
    read_choice()  # re-prompt without redrawing the menu
  end

  # --- Helpers ---

  defp prompt(label) do
    case IO.gets(label) do
      :eof -> :eof
      nil  -> :eof
      bin  -> bin |> to_string() |> String.trim()
    end
  end

  defp safe_call(fun, opts) do
    fallback = Keyword.get(opts, :fallback, fn -> :ok end)
    try do
      case fun.() do
        :ok -> :ok
        {:ok, []} ->
          IO.puts("No records.")
          :ok
        {:ok, list} when is_list(list) ->
          render_table(list)
          :ok
        {:ok, val} ->
          IO.inspect(val, label: "OK")
          :ok
        other ->
          IO.inspect(other, label: "Result")
          :ok
      end
    rescue
      e in UndefinedFunctionError ->
        IO.puts("Missing implementation: #{Exception.message(e)}")
        fallback.()
      e ->
        IO.puts("Error: #{Exception.message(e)}")
        fallback.()
    catch
      kind, reason ->
        IO.puts("Error (#{inspect(kind)}): #{inspect(reason)}")
        fallback.()
    end
  end

  defp render_table([]), do: :ok
  defp render_table(rows) when is_list(rows) do
    cols = ~w(npi name taxonomy phone address)
    widths =
      for c <- cols do
        Enum.max([String.length(c) | Enum.map(rows, &String.length(Map.get(&1, c, "")))])
      end

    pad  = fn s, w -> s <> String.duplicate(" ", w - String.length(s)) end
    line = fn ch -> IO.puts(Enum.map(widths, &String.duplicate(ch, &1)) |> Enum.join(" ")) end

    header =
      cols
      |> Enum.zip(widths)
      |> Enum.map(fn {c, w} -> pad.(c, w) end)
      |> Enum.join(" ")

    IO.puts(header)
    line.("-")

    Enum.each(rows, fn row ->
      IO.puts(
        cols
        |> Enum.zip(widths)
        |> Enum.map(fn {c, w} -> pad.(Map.get(row, c, ""), w) end)
        |> Enum.join(" ")
      )
    end)
  end
end
