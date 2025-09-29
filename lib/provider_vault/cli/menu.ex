defmodule ProviderVault.CLI.Menu do
  @moduledoc """
  Interactive menu loop for ProviderVault.

  Renders the menu, reads input, and dispatches to actions.
  Non-UI logic is delegated to dedicated modules (CSV, Excel, NPPES, etc.).
  """

  # We reference optional modules; suppress warnings if they compile after this one.
  @compile {:no_warn_undefined, ProviderVault.CSV}
  @compile {:no_warn_undefined, ProviderVault.Excel.Convert}
  @compile {:no_warn_undefined, ProviderVault.Ingestion.NppesFetcher}

  @spec main() :: :ok
  def main, do: loop()

  defp loop do
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

    case prompt("\nEnter number: ") do
      "10" ->
        IO.puts("Goodbye!")
        :ok

      choice ->
        dispatch(choice)
    end
  end

  # --- Dispatch ---

  defp dispatch("1") do
    last = prompt("Last name: ")
    first = prompt("First name: ")
    npi = prompt("NPI (10 digits): ")

    safe_call(fn -> ProviderVault.CSV.add_provider(npi, last, first) end,
      fallback: fn ->
        IO.puts("Add not implemented yet.")
        :ok
      end
    )

    loop()
  end

  defp dispatch("2") do
    safe_call(fn -> ProviderVault.CSV.list_providers() end,
      fallback: fn ->
        IO.puts("List not implemented yet.")
        :ok
      end
    )

    loop()
  end

  defp dispatch("3") do
    npi = prompt("NPI: ")

    safe_call(fn -> ProviderVault.CSV.find_by_npi(npi) end,
      fallback: fn ->
        IO.puts("Find by NPI not implemented yet.")
        :ok
      end
    )

    loop()
  end

  defp dispatch("4") do
    npi = prompt("NPI to edit: ")
    # Collect fields to edit; simplistic demo:
    last = prompt("New Last (blank to skip): ")
    first = prompt("New First (blank to skip): ")

    safe_call(fn -> ProviderVault.CSV.edit_provider(npi, last, first) end,
      fallback: fn ->
        IO.puts("Edit not implemented yet.")
        :ok
      end
    )

    loop()
  end

  defp dispatch("5") do
    npi = prompt("NPI to delete: ")

    safe_call(fn -> ProviderVault.CSV.delete_provider(npi) end,
      fallback: fn ->
        IO.puts("Delete not implemented yet.")
        :ok
      end
    )

    loop()
  end

  defp dispatch("6") do
    name = prompt("Search name (partial): ")

    safe_call(fn -> ProviderVault.CSV.search_by_name(name) end,
      fallback: fn ->
        IO.puts("Search not implemented yet.")
        :ok
      end
    )

    loop()
  end

  defp dispatch("7") do
    safe_call(fn -> ProviderVault.CSV.import_sample_data() end,
      fallback: fn ->
        IO.puts("Import sample data not implemented yet.")
        :ok
      end
    )

    loop()
  end

  defp dispatch("8") do
    confirm = prompt("Type 'YES' to clear all records: ")

    if confirm == "YES" do
      safe_call(fn -> ProviderVault.CSV.clear_all() end,
        fallback: fn ->
          IO.puts("Clear all not implemented yet.")
          :ok
        end
      )
    else
      IO.puts("Cancelled.")
    end

    loop()
  end

  defp dispatch("9") do
    xlsx = prompt("Path to .xlsx: ")
    sheet_in = prompt("Sheet (index starting at 1 OR name): ")

    opts =
      case Integer.parse(sheet_in) do
        {idx, ""} when idx > 0 -> [sheet: idx]
        _ -> [sheet: sheet_in]
      end

    safe_call(
      fn -> ProviderVault.Excel.Convert.convert_file(xlsx, opts) end,
      fallback: fn ->
        IO.puts("Excel -> CSV not implemented yet.")
        :ok
      end
    )

    loop()
  end

  defp dispatch("11") do
    # Either use configured URL or prompt:
    url = prompt("NPPES monthly ZIP URL (blank to use env NPPES_URL): ")
    dest = prompt("Destination dir (default priv/data): ")
    dest_dir = if dest == "", do: "priv/data", else: dest

    safe_call(
      fn ->
        if url == "" do
          # try module default/env-driven flow
          ProviderVault.Ingestion.NppesFetcher.run_monthly()
        else
          ProviderVault.Ingestion.NppesFetcher.fetch_and_save!(url, to: dest_dir)
        end
      end,
      fallback: fn ->
        IO.puts("NPPES fetcher not implemented yet.")
        :ok
      end
    )

    loop()
  end

  defp dispatch(_other) do
    IO.puts("Invalid choice")
    loop()
  end

  # --- Helpers ---

  defp prompt(label) do
    IO.gets(label)
    |> case do
      :eof -> ""
      nil -> ""
      bin -> to_string(bin) |> String.trim()
    end
  end

  # Run a function; if the module/function is missing or raises, print a friendly message.
  defp safe_call(fun, opts) do
    fallback = Keyword.get(opts, :fallback, fn -> :ok end)

    try do
      case fun.() do
        :ok ->
          :ok

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
    # choose the columns to show and order them
    cols = ~w(npi name taxonomy phone address)

    # compute widths
    widths =
      for c <- cols do
        Enum.max([String.length(c) | Enum.map(rows, &String.length(Map.get(&1, c, "")))])
      end

    # helpers
    pad = fn s, w -> s <> String.duplicate(" ", w - String.length(s)) end
    line = fn ch -> IO.puts(Enum.map(widths, &String.duplicate(ch, &1)) |> Enum.join(" ")) end

    # header
    header =
      cols
      |> Enum.zip(widths)
      |> Enum.map(fn {c, w} -> pad.(c, w) end)
      |> Enum.join(" ")

    IO.puts(header)
    line.("-")

    # rows
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
