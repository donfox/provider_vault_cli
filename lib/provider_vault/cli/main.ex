defmodule ProviderVault.CLI.Main do
  alias Mix.Shell.IO, as: Shell
  alias ProviderVault.{Providers, Storage, Validators}
  alias ProviderVault.CLI.Menu
  @data_file "priv/data/providers.csv"

  # Helpers
  defp data_file, do: @data_file

  # PUBLIC ENTRYPOINT
  def start do
    welcome_message()
    ensure_storage()
    loop()
  end

  # ── UI Loop ───────────────────────────────────────────────────────────────────
  defp welcome_message do
    Shell.cmd("clear")
    Shell.info("== Provider Vault CLI ==")
    Shell.info("Manage simple medical provider records (CSV-backed).")
  end

  defp loop do
    Menu.print_menu()

    case Menu.prompt_choice() do
      :add ->
        add_provider()
        loop()

      :list ->
        list_providers()
        loop()

      :find_npi ->
        find_by_npi()
        loop()

      :search_name ->
        search_by_name()
        loop()

      :edit ->
        edit_provider()
        loop()

      :delete ->
        delete_provider()
        loop()

      :import_samples ->
        import_samples()
        loop()

      :clear_all ->
        clear_all()
        loop()

      :convert_excel ->
        Menu.excel_to_csv()
        loop()

      :excel_to_csv ->
        Menu.excel_to_csv()
        loop()

      :exit ->
        Shell.info("Bye!")
        :init.stop()
    end
  end

  # ── Bootstrapping / Storage ──────────────────────────────────────────────────
  defp ensure_storage do
    case Storage.init_csv(data_file()) do
      :created ->
        Shell.info("Initialized new CSV store at #{data_file()}.")

      :ok ->
        :ok
    end
  end

  defp load_providers do
    Storage.stream_csv(data_file()) |> Enum.to_list()
  end

  defp save_all(providers) when is_list(providers) do
    # clear then rewrite the CSV
    :ok = Storage.clear_csv(data_file())
    Enum.each(providers, fn p -> Storage.append_csv(data_file(), p) end)
    :ok
  end

  # ── Actions ──────────────────────────────────────────────────────────────────
  defp list_providers do
    Shell.info("\n-- Providers --")

    providers = load_providers()

    if providers == [] do
      Shell.info("No providers found. Use 'Add provider' or 'Import sample data'.")
    else
      providers
      |> Enum.with_index(1)
      |> Enum.each(fn {p, idx} -> Shell.info("#{idx}. " <> Providers.format(p)) end)
    end
  end

  defp add_provider do
    Shell.info("\n-- Add Provider --")

    npi =
      Shell.prompt("NPI (10 digits): ")
      |> String.trim()
      |> Validators.require_npi()

    name =
      Shell.prompt("Name (Last, First or Org): ")
      |> String.trim()
      |> Validators.require_nonempty("Name is required")

    taxonomy = Shell.prompt("Taxonomy (e.g., 207Q00000X): ") |> String.trim()
    phone = Shell.prompt("Phone (optional): ") |> String.trim()
    address = Shell.prompt("Address (optional): ") |> String.trim()

    provider = %Providers.Provider{
      npi: npi,
      name: name,
      taxonomy: taxonomy,
      phone: phone,
      address: address
    }

    case Storage.insert_if_missing(data_file(), provider) do
      :inserted ->
        Shell.info("Saved.")

      :exists ->
        Shell.error("A provider with NPI #{npi} already exists. Not saved.")
    end
  end

  defp find_by_npi do
    Shell.info("\n-- Find by NPI --")

    npi =
      Shell.prompt("Enter NPI: ")
      |> String.trim()
      |> Validators.require_npi()

    load_providers()
    |> Enum.find(&(&1.npi == npi))
    |> case do
      nil -> Shell.info("No provider with NPI #{npi} found.")
      provider -> Shell.info(Providers.format(provider))
    end
  end

  defp search_by_name do
    Shell.info("\n-- Search by Name --")

    term = Shell.prompt("Enter partial name: ") |> String.trim()

    providers =
      load_providers()
      |> Enum.filter(fn p ->
        String.contains?(String.downcase(p.name), String.downcase(term))
      end)

    if providers == [] do
      Shell.info("No matches.")
    else
      providers
      |> Enum.with_index(1)
      |> Enum.each(fn {p, i} -> Shell.info("#{i}. " <> Providers.format(p)) end)
    end
  end

  defp edit_provider do
    Shell.info("\n-- Edit Provider --")

    providers = load_providers()

    if providers == [] do
      Shell.info("No providers to edit.")
    else
      providers
      |> Enum.with_index(1)
      |> Enum.each(fn {p, i} -> Shell.info("#{i}. " <> Providers.format(p)) end)

      idx_input = Shell.prompt("\nChoose number to edit: ") |> String.trim()

      case Integer.parse(idx_input) do
        {n, ""} when n >= 1 and n <= length(providers) ->
          idx = n - 1
          p = Enum.at(providers, idx)

          Shell.info("\nEditing #{p.name} (NPI #{p.npi}) — leave blank to keep current.")

          new_name =
            Shell.prompt("Name [#{p.name}]: ")
            |> String.trim()
            |> default_if_blank(p.name)

          new_taxonomy =
            Shell.prompt("Taxonomy [#{p.taxonomy}]: ")
            |> String.trim()
            |> default_if_blank(p.taxonomy)

          new_phone =
            Shell.prompt("Phone [#{p.phone}]: ")
            |> String.trim()
            |> default_if_blank(p.phone)

          new_address =
            Shell.prompt("Address [#{p.address}]: ")
            |> String.trim()
            |> default_if_blank(p.address)

          updated = %Providers.Provider{
            p
            | name: new_name,
              taxonomy: new_taxonomy,
              phone: new_phone,
              address: new_address
          }

          save_all(List.replace_at(providers, idx, updated))
          Shell.info("Saved.")

        _ ->
          Shell.error("Invalid selection.")
      end
    end
  end

  defp clear_all do
    Shell.info("\n-- Clear All Records --")

    case String.trim(Shell.prompt("Type ERASE to delete ALL records: ")) do
      "ERASE" ->
        save_all([])
        Shell.info("All records cleared.")

      _ ->
        Shell.info("Canceled.")
    end
  end

  defp import_samples do
    Shell.info("\n-- Import Samples --")

    samples = [
      %Providers.Provider{
        npi: "1234567890",
        name: "Doe, Jane",
        taxonomy: "207Q00000X",
        phone: "555-0101",
        address: "123 Main St"
      },
      %Providers.Provider{
        npi: "2345678901",
        name: "Smith, John",
        taxonomy: "1223G0001X",
        phone: "555-0303",
        address: "77 Dental Ave"
      }
    ]

    results = Enum.map(samples, fn p -> Storage.insert_if_missing(data_file(), p) end)
    inserted = Enum.count(results, &(&1 == :inserted))
    exists = Enum.count(results, &(&1 == :exists))

    Shell.info("Imported #{inserted} new provider(s). Skipped #{exists} duplicate(s).")
  end

  defp delete_provider do
    Shell.info("\n-- Delete Provider --")

    providers = load_providers()

    if providers == [] do
      Shell.info("No providers to delete.")
    else
      providers
      |> Enum.with_index(1)
      |> Enum.each(fn {p, i} -> Shell.info("#{i}. #{p.name} | NPI: #{p.npi}") end)

      idx_input = Shell.prompt("\nChoose number to delete: ") |> String.trim()

      case Integer.parse(idx_input) do
        {n, ""} when n >= 1 and n <= length(providers) ->
          idx = n - 1
          p = Enum.at(providers, idx)

          case String.trim(Shell.prompt("Type DELETE to remove #{p.name} (NPI #{p.npi}): ")) do
            "DELETE" ->
              new_list = List.delete_at(providers, idx)
              save_all(new_list)
              Shell.info("Deleted.")

            _ ->
              Shell.info("Canceled.")
          end

        _ ->
          Shell.error("Invalid selection.")
      end
    end
  end

  # ── Utils ────────────────────────────────────────────────────────────────────
  defp default_if_blank("", d), do: d
  defp default_if_blank(s, _), do: s
end
