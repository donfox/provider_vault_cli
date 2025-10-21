defmodule ProviderVault.Storage do
  @moduledoc """
  Unified CSV-backed storage for provider records.

  Columns: `npi, name, taxonomy, phone, address`

  ## Features

  - Dual API: maps for CLI, structs for tests
  - NPI deduplication (last write wins)
  - Legacy `provders.csv` support (pads to 5 columns)
  - Configurable via `PROVIDER_VAULT_DATA_DIR` env var
  - Default location: `priv/data/providers.csv`

  ## Usage

      # Map-based (CLI)
      Storage.list_providers()
      Storage.add_provider(npi, name, taxonomy, phone, address)
      Storage.find_by_npi(npi)
      Storage.search_by_name("Smith")

      # Struct-based (testing)
      Storage.stream_csv(path) |> Enum.take(10)
      Storage.append_csv(path, %Provider{...})
  """

  defmodule Provider do
    @moduledoc """
    Provider record struct.

    Required: `:npi`, `:name`
    Optional: `:taxonomy`, `:phone`, `:address`
    """
    @enforce_keys [:npi, :name]
    defstruct [:npi, :name, :taxonomy, :phone, :address]
  end

  alias NimbleCSV.RFC4180, as: RFC

  @headers ~w(npi name taxonomy phone address)
  @header_line "npi,name,taxonomy,phone,address\n"

  # =============================================================================
  # PUBLIC API - Map-based (used by CLI/Menu)
  # =============================================================================

  @doc "List all providers as maps (for menu Option 2)."
  @spec list_providers() :: [map()]
  def list_providers, do: all()

  @doc "Alias for list_providers/0."
  @spec list() :: [map()]
  def list, do: all()

  @doc """
  Add or update a provider row (dedupe by NPI).
  `name` should be \"Last, First\".
  Returns :ok or {:error, reason}.
  """
  @spec add_provider(String.t(), String.t(), String.t(), String.t(), String.t()) ::
          :ok | {:error, term()}
  def add_provider(npi, name, taxonomy, phone, address) do
    File.mkdir_p!(data_dir())

    rows =
      case pick_file() do
        nil -> []
        file -> read_all_maps(file)
      end

    new = %{
      "npi" => String.trim(npi),
      "name" => String.trim(name),
      "taxonomy" => String.trim(taxonomy),
      "phone" => String.trim(phone),
      "address" => String.trim(address)
    }

    updated =
      rows
      |> Enum.reject(&(&1["npi"] == new["npi"]))
      |> Kernel.++([new])

    write_all_maps!(preferred_file(), updated)
    :ok
  rescue
    e -> {:error, e}
  end

  @doc "Back-compat: 6-arity add (last, first as separate args)."
  @spec add_provider(String.t(), String.t(), String.t(), String.t(), String.t(), String.t()) ::
          :ok | {:error, term()}
  def add_provider(npi, last, first, taxonomy, phone, address) do
    add_provider(npi, "#{last}, #{first}", taxonomy, phone, address)
  end

  @doc "Return all providers as a list of maps."
  @spec all() :: [map()]
  def all do
    case pick_file() do
      nil -> []
      file -> read_all_maps(file)
    end
  end

  @doc "Find a provider by NPI. Returns map | nil."
  @spec find_by_npi(String.t()) :: map() | nil
  def find_by_npi(npi), do: Enum.find(all(), &(&1["npi"] == npi))

  @doc "Delete a provider by NPI."
  @spec delete_provider(String.t()) :: :ok | {:error, term()}
  def delete_provider(npi) do
    rows = Enum.reject(all(), &(&1["npi"] == npi))
    write_all_maps!(preferred_file(), rows)
    :ok
  rescue
    e -> {:error, e}
  end

  @doc "Edit a provider by NPI, merging fields from attrs (string keys)."
  @spec edit_provider(String.t(), map()) :: :ok | {:error, term()}
  def edit_provider(npi, attrs) when is_map(attrs) do
    allowed = Map.take(attrs, @headers)

    rows =
      all()
      |> Enum.map(fn row ->
        if row["npi"] == npi, do: Map.merge(row, allowed), else: row
      end)

    write_all_maps!(preferred_file(), rows)
    :ok
  rescue
    e -> {:error, e}
  end

  @doc "Search by partial match on provider name (case-insensitive)."
  @spec search_by_name(String.t()) :: :ok
  def search_by_name(term) when is_binary(term) do
    term_down = String.downcase(term)

    all()
    |> Enum.filter(fn
      %{"name" => name} -> String.contains?(String.downcase(name), term_down)
      _ -> false
    end)
    |> case do
      [] ->
        IO.puts("No matches found.")

      matches ->
        IO.puts("Found #{length(matches)} match(es):")

        Enum.each(matches, fn p ->
          IO.puts("#{p["npi"]} - #{p["name"]} - #{p["taxonomy"]}")
        end)
    end
  end

  @doc "Clear all records, leaving only the header."
  @spec clear_all() :: :ok
  def clear_all do
    clear_csv(preferred_file())
  end

  @doc "Display provider statistics."
  @spec stats() :: {:ok, map()} | {:error, term()}
  def stats do
    providers = list_providers()
    total = length(providers)

    IO.puts("""
    Provider Statistics
    --------------------
    Total providers: #{total}
    """)

    {:ok, %{total_providers: total}}
  end

  @doc "Current file being used (debug)."
  @spec current_file() :: String.t() | nil
  def current_file, do: pick_file()

  @doc "Row count (debug)."
  @spec count() :: non_neg_integer()
  def count, do: length(all())

  @doc "RFC4180 dump helper used by the Excel converter."
  @spec dump_to_iodata([[String.t()]]) :: iodata()
  def dump_to_iodata(rows) when is_list(rows), do: RFC.dump_to_iodata(rows)

  # =============================================================================
  # PUBLIC API - Struct-based (used by tests)
  # =============================================================================

  @doc """
  Initialize CSV if missing.
  Returns :created if file was created, :ok if it already existed.
  """
  @spec init_csv(String.t()) :: :ok | :created
  def init_csv(path) do
    if File.exists?(path) do
      :ok
    else
      File.mkdir_p!(Path.dirname(path))
      File.write!(path, @header_line)
      :created
    end
  end

  @doc "Clear CSV, leaving only the header."
  @spec clear_csv(String.t()) :: :ok
  def clear_csv(path) do
    File.write!(path, @header_line)
    :ok
  end

  @doc "Check if an NPI already exists in the CSV."
  @spec has_npi?(String.t(), String.t()) :: boolean()
  def has_npi?(path, npi) do
    stream_csv(path) |> Enum.any?(fn %Provider{npi: existing} -> existing == npi end)
  end

  @doc "Append a provider if its NPI is not present; returns :inserted or :exists."
  @spec insert_if_missing(String.t(), Provider.t()) :: :inserted | :exists
  def insert_if_missing(path, %Provider{npi: npi} = p) do
    if has_npi?(path, npi) do
      :exists
    else
      append_csv(path, p)
      :inserted
    end
  end

  @doc "Append a provider struct to the CSV."
  @spec append_csv(String.t(), Provider.t()) :: :ok | {:error, term()}
  def append_csv(path, %Provider{} = p) do
    line =
      [p.npi, p.name, p.taxonomy || "", p.phone || "", p.address || ""]
      |> Enum.map(&escape_csv/1)
      |> Enum.join(",")
      |> Kernel.<>("\n")

    File.write(path, line, [:append])
  end

  @doc "Stream providers as structs from a CSV file."
  @spec stream_csv(String.t()) :: Enumerable.t()
  def stream_csv(path) do
    if File.exists?(path) do
      path
      |> File.stream!()
      |> Stream.drop(1)
      |> Stream.map(&String.trim_trailing(&1, "\n"))
      |> Stream.reject(&(&1 == ""))
      |> Stream.map(&parse_line_to_struct/1)
    else
      Stream.map([], fn _ -> nil end)
    end
  end

  # =============================================================================
  # PRIVATE - Path resolution
  # =============================================================================

  defp data_dir do
    case System.get_env("PROVIDER_VAULT_DATA_DIR") do
      nil -> Path.expand("../../priv/data", __DIR__)
      dir -> Path.expand(dir)
    end
  end

  defp preferred_file, do: Path.join(data_dir(), "providers.csv")
  defp legacy_file, do: Path.join(data_dir(), "provders.csv")

  defp pick_file do
    cond do
      File.exists?(preferred_file()) -> preferred_file()
      File.exists?(legacy_file()) -> legacy_file()
      true -> nil
    end
  end

  # =============================================================================
  # PRIVATE - Map-based reading/writing (for CLI)
  # =============================================================================

  defp write_all_maps!(file, rows) do
    data =
      rows
      |> Enum.map(&map_to_row(&1, @headers))
      |> RFC.dump_to_iodata()

    iodata = [Enum.join(@headers, ","), "\n", data]
    File.write!(file, iodata)
  end

  defp read_all_maps(file) do
    body = File.read!(file)

    rows =
      body
      |> strip_bom()
      |> RFC.parse_string()
      |> maybe_drop_header()
      |> Enum.map(&sanitize_row/1)

    Enum.map(rows, fn row ->
      row
      |> pad_to(length(@headers))
      |> row_to_map(@headers)
    end)
  end

  defp maybe_drop_header([first | rest]) do
    if Enum.map(first, &String.downcase/1) == @headers, do: rest, else: [first | rest]
  end

  defp maybe_drop_header(rows), do: rows

  defp sanitize_row(row), do: Enum.map(row, &String.trim/1)

  defp strip_bom(<<239, 187, 191, rest::binary>>), do: rest
  defp strip_bom(bin), do: bin

  defp row_to_map(row, headers), do: headers |> Enum.zip(row) |> Map.new()
  defp map_to_row(map, headers), do: Enum.map(headers, &Map.get(map, &1, ""))

  defp pad_to(list, n) do
    case length(list) do
      ^n -> list
      k when k < n -> list ++ List.duplicate("", n - k)
      _k -> Enum.take(list, n)
    end
  end

  # =============================================================================
  # PRIVATE - Struct-based parsing (for tests)
  # =============================================================================

  defp parse_line_to_struct(line) do
    [npi, name, tax, phone, addr] = split_csv_line(line)

    %Provider{
      npi: npi,
      name: name,
      taxonomy: blank_to_nil(tax),
      phone: blank_to_nil(phone),
      address: blank_to_nil(addr)
    }
  end

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(s), do: s

  defp escape_csv(nil), do: ""

  defp escape_csv(str) when is_binary(str) do
    needs = String.contains?(str, [",", "\"", "\n", "\r"])
    s = String.replace(str, "\"", "\"\"")
    if needs, do: "\"#{s}\"", else: s
  end

  defp split_csv_line(line) when is_binary(line) do
    do_split(String.graphemes(line), [], "", false)
  end

  defp do_split([], fields, field, _in_quotes) do
    fields ++ [field]
  end

  defp do_split(["\"" | rest], fields, field, false) do
    do_split(rest, fields, field, true)
  end

  defp do_split(["\"" | rest], fields, field, true) do
    case rest do
      ["\"" | rest2] ->
        do_split(rest2, fields, field <> "\"", true)

      _ ->
        do_split(rest, fields, field, false)
    end
  end

  defp do_split(["," | rest], fields, field, false) do
    do_split(rest, fields ++ [field], "", false)
  end

  defp do_split([c | rest], fields, field, in_quotes) do
    do_split(rest, fields, field <> c, in_quotes)
  end
end
