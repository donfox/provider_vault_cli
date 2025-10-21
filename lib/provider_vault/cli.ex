defmodule ProviderVault.CLI do
  @moduledoc """
  Interactive CLI for managing provider records.

  Handles command-line flags (--help, --version) and provides an interactive menu.
  """

  @compile {:no_warn_undefined, ProviderVault.Storage}
  @compile {:no_warn_undefined, ProviderVault.NppesFetcher}

  @type argv :: [String.t()]

  # =============================================================================
  # PUBLIC API
  # =============================================================================

  @doc """
  Main entry point for the CLI.

  Handles --help, --version flags, or launches the interactive menu.
  """
  @spec main(argv()) :: :ok | {:error, term()}
  def main(argv \\ []) do
    cond do
      "--help" in argv or "-h" in argv ->
        print_help()
        :ok

      "--version" in argv or "-v" in argv ->
        print_version()
        :ok

      true ->
        # Launch interactive menu
        loop()
    end
  end

  @doc "Convenience wrapper for interactive mode (same as main([]))."
  @spec start() :: :ok | {:error, term()}
  def start, do: main([])

  # =============================================================================
  # INTERACTIVE MENU
  # =============================================================================

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
    7) Clear all records
    8) View statistics
    9) Fetch latest NPPES provider data (on demand)
    0) Exit
    """)
  end

  defp read_choice do
    case prompt("\nEnter number: ") do
      :eof ->
        IO.puts("\nGoodbye.")
        :ok

      "0" ->
        IO.puts("Goodbye!")
        :ok

      choice when choice in ~w(1 2 3 4 5 6 7 8 9 0) ->
        dispatch(choice)

      _ ->
        IO.puts("Invalid choice (try 1–0).")
        read_choice()
    end
  end

  # =============================================================================
  # MENU DISPATCH
  # =============================================================================

  defp dispatch("1") do
    last = prompt("Last name: ")
    first = prompt("First name: ")
    npi = prompt("NPI (10 digits): ")
    taxonomy = prompt("Taxonomy (default 207Q00000X): ")
    phone = prompt("Phone (e.g. 555-0101): ")
    address = prompt("Address: ")

    taxonomy = if taxonomy == "", do: "207Q00000X", else: taxonomy
    phone = if phone == "", do: "555-0101", else: phone
    address = if address == "", do: "123 Main St", else: address

    name = "#{last}, #{first}"

    safe_call(
      fn -> ProviderVault.Storage.add_provider(npi, name, taxonomy, phone, address) end,
      fallback: fn ->
        IO.puts("Add provider failed or not implemented yet.")
        :ok
      end
    )

    loop()
  end

  defp dispatch("2") do
    safe_call(
      fn -> {:ok, ProviderVault.Storage.list_providers()} end,
      fallback: fn ->
        IO.puts("List not implemented yet.")
        :ok
      end
    )

    loop()
  end

  defp dispatch("3") do
    npi = prompt("NPI: ")

    safe_call(
      fn -> ProviderVault.Storage.find_by_npi(npi) end,
      fallback: fn ->
        IO.puts("Find by NPI not implemented yet.")
        :ok
      end
    )

    loop()
  end

  defp dispatch("4") do
    npi = prompt("NPI to edit: ")
    last = prompt("New Last (blank to skip): ")
    first = prompt("New First (blank to skip): ")

    attrs =
      %{}
      |> (fn m ->
            if last != "" or first != "" do
              Map.put(m, "name", String.trim("#{last}, #{first}"))
            else
              m
            end
          end).()

    safe_call(
      fn -> ProviderVault.Storage.edit_provider(npi, attrs) end,
      fallback: fn ->
        IO.puts("Edit not implemented yet.")
        :ok
      end
    )

    loop()
  end

  defp dispatch("5") do
    npi = prompt("NPI to delete: ")

    safe_call(
      fn -> ProviderVault.Storage.delete_provider(npi) end,
      fallback: fn ->
        IO.puts("Delete not implemented yet.")
        :ok
      end
    )

    loop()
  end

  defp dispatch("6") do
    name = prompt("Search name (partial): ")

    safe_call(
      fn -> ProviderVault.Storage.search_by_name(name) end,
      fallback: fn ->
        IO.puts("Search not implemented yet.")
        :ok
      end
    )

    loop()
  end

  defp dispatch("7") do
    confirm = prompt("Type 'YES' to clear all records: ")

    if confirm == "YES" do
      safe_call(
        fn -> ProviderVault.Storage.clear_all() end,
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

  defp dispatch("8") do
    safe_call(
      fn -> ProviderVault.Storage.stats() end,
      fallback: fn ->
        IO.puts("Stats not implemented yet.")
        :ok
      end
    )

    loop()
  end

  defp dispatch("9") do
    url_input = prompt("NPPES monthly ZIP URL (blank to auto-fetch current): ")
    dest = prompt("Destination dir (default priv/data): ")
    dest_dir = if dest == "", do: "priv/data", else: dest

    case url_input do
      "" ->
        safe_call(
          fn ->
            path = ProviderVault.NppesFetcher.fetch_current_month!()
            IO.puts("Downloaded to: #{path}")
          end,
          fallback: fn ->
            IO.puts("Auto-fetch failed. Please try again.")
            :ok
          end
        )

      url ->
        safe_call(
          fn ->
            path = ProviderVault.NppesFetcher.fetch!(url, to: dest_dir)
            IO.puts("Downloaded to: #{path}")
          end,
          fallback: fn ->
            IO.puts("Fetch failed. Please check the URL and try again.")
            :ok
          end
        )
    end

    loop()
  end

  defp dispatch(_other) do
    IO.puts("Invalid choice")
    read_choice()
  end

  # =============================================================================
  # HELPERS
  # =============================================================================

  defp prompt(label) do
    case IO.gets(label) do
      :eof -> :eof
      nil -> :eof
      bin -> bin |> to_string() |> String.trim()
    end
  end

  defp safe_call(fun, opts) do
    fallback = Keyword.get(opts, :fallback, fn -> :ok end)

    try do
      case fun.() do
        :ok -> :ok
        {:ok, []} -> IO.puts("No records.")
        {:ok, list} when is_list(list) -> render_table(list)
        {:ok, val} -> IO.inspect(val, label: "OK")
        other -> IO.inspect(other, label: "Result")
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

    pad = fn s, w -> s <> String.duplicate(" ", w - String.length(s)) end
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

  # =============================================================================
  # HELP & VERSION
  # =============================================================================

  defp print_help do
    IO.puts("""
    Provider Vault CLI

    Usage:
      provider_vault_cli [--help | --version]
    Without flags, an interactive menu will be shown.
    """)
  end

  defp print_version do
    vsn =
      case Application.spec(:provider_vault_cli, :vsn) do
        nil -> "dev"
        v when is_list(v) -> List.to_string(v)
        v -> to_string(v)
      end

    app =
      case Application.spec(:provider_vault_cli, :applications) do
        _ -> "provider_vault_cli"
      end

    IO.puts("#{app} #{vsn}")
  end
end
