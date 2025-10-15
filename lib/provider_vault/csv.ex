defmodule ProviderVault.CSV do
  @moduledoc """
  CSV-backed storage for simple provider records.

  Columns (in order):
  npi, name, taxonomy, phone, address

  - Stores under a stable data dir (env override or repo priv/data)
  - Reads legacy `provders.csv` (2 cols) and pads it
  - Dedupes by NPI on write (last write wins)
  """

  @headers ~w(npi name taxonomy phone address)
  alias NimbleCSV.RFC4180, as: RFC

  # --------------------
  # Public API
  # --------------------

  @doc "List providers (menu Option 2 expects this)."
  @spec list_providers() :: [map()]
  def list_providers, do: all()

  @doc "Alias in case anything calls `list/0`."
  @spec list() :: [map()]
  def list, do: all()

  @doc """
  Add or update a provider row (dedupe by NPI).
  `name` should be \"Last, First\".
  """
  @spec add_provider(String.t(), String.t(), String.t(), String.t(), String.t()) ::
          :ok | {:error, term()}
  def add_provider(npi, name, taxonomy, phone, address) do
    File.mkdir_p!(data_dir())

    rows =
      case pick_file() do
        nil -> []
        file -> read_all(file)
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
      # dedupe by NPI
      |> Enum.reject(&(&1["npi"] == new["npi"]))
      |> Kernel.++([new])

    write_all!(preferred_file(), updated)
    :ok
  rescue
    e -> {:error, e}
  end

  @doc "Back-compat shim if anything still calls 6-arity add."
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
      file -> read_all(file)
    end
  end

  @doc "Find a provider by NPI. Returns `map | nil`."
  @spec find_by_npi(String.t()) :: map() | nil
  def find_by_npi(npi), do: Enum.find(all(), &(&1["npi"] == npi))

  @doc "Delete a provider by NPI."
  @spec delete_provider(String.t()) :: :ok | {:error, term()}
  def delete_provider(npi) do
    rows = Enum.reject(all(), &(&1["npi"] == npi))
    write_all!(preferred_file(), rows)
    :ok
  rescue
    e -> {:error, e}
  end

  @doc "Edit a provider by `npi`, merging fields from `attrs` (string keys)."
  @spec edit_provider(String.t(), map()) :: :ok | {:error, term()}
  def edit_provider(npi, attrs) when is_map(attrs) do
    allowed = Map.take(attrs, @headers)

    rows =
      all()
      |> Enum.map(fn row ->
        if row["npi"] == npi, do: Map.merge(row, allowed), else: row
      end)

    write_all!(preferred_file(), rows)
    :ok
  rescue
    e -> {:error, e}
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

  # --------------------
  # Internals
  # --------------------

  defp write_all!(file, rows) do
    data =
      rows
      |> Enum.map(&map_to_row(&1, @headers))
      |> RFC.dump_to_iodata()

    iodata = [Enum.join(@headers, ","), "\n", data]
    File.write!(file, iodata)
  end

  # REPLACE your existing read_all/1 with this:
  defp read_all(file) do
    body = File.read!(file)

    rows =
      body
      |> strip_bom()
      # parse first…
      |> RFC.parse_string()
      # …then drop header if present
      |> maybe_drop_header()
      |> Enum.map(&sanitize_row/1)

    Enum.map(rows, fn row ->
      row
      # legacy 2-col → pad
      |> pad_to(length(@headers))
      |> row_to_map(@headers)
    end)
  end

  # ADD these helpers right below read_all/1:
  defp maybe_drop_header([first | rest]) do
    if Enum.map(first, &String.downcase/1) == @headers, do: rest, else: [first | rest]
  end

  defp maybe_drop_header(rows), do: rows

  defp sanitize_row(row), do: Enum.map(row, &String.trim/1)

  # -------- Path resolution (no more “file in repo root”) --------

  # 1) If PROVIDER_VAULT_DATA_DIR is set, use it.
  # 2) Else use repo-relative priv/data via __DIR__.
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

  # -------- CSV helpers --------
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

  def stats do
    with {:ok, providers} <- ProviderVault.CSV.list_providers() do
      total = length(providers)

      IO.puts("""
      Provider Statistics
      --------------------
      Total providers: #{total}
      """)

      {:ok, %{total_providers: total}}
    else
      error -> {:error, error}
    end
  end
end
