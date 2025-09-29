defmodule ProviderVault.CSV do
  @moduledoc """
  CSV helpers and a minimal CSV-backed store for providers.

  Schema (headers):
    npi,name,taxonomy,phone,address

  Files:
    priv/data/providers.csv   (preferred)
    priv/data/provders.csv    (legacy; still read if present)
  """

  # Keep these delegates so callers like Excel.Convert can use them.
  defdelegate dump_to_iodata(rows), to: NimbleCSV.RFC4180, as: :dump_to_iodata
  defdelegate parse_string(bin), to: NimbleCSV.RFC4180, as: :parse_string
  defdelegate parse_string(bin, opts), to: NimbleCSV.RFC4180, as: :parse_string

  alias NimbleCSV.RFC4180, as: RFC

  @data_dir "priv/data"
  @preferred_file Path.join(@data_dir, "providers.csv")
  @legacy_file    Path.join(@data_dir, "provders.csv")
  @headers ~w(npi name taxonomy phone address)

  @doc "Return all providers (list of maps with string keys)."
  @spec list_providers() :: {:ok, [map()]} | {:error, term()}
  def list_providers do
    case pick_file() do
      nil  -> {:ok, []}
      file -> {:ok, read_all(file)}
    end
  rescue
    e -> {:error, e}
  end

  @doc """
  Create the CSV with two sample rows **if it doesn't exist**.
  Does not overwrite existing files.
  """
  @spec import_sample_data() :: :ok | {:error, term()}
  def import_sample_data do
    File.mkdir_p!(@data_dir)

    cond do
      File.exists?(@preferred_file) or File.exists?(@legacy_file) ->
        :ok

      true ->
        rows = [
          %{"npi" => "1234567893", "name" => "Doe, Jane",  "taxonomy" => "207Q00000X",  "phone" => "555-0101", "address" => "123 Main St"},
          %{"npi" => "2345678901", "name" => "Smith, John","taxonomy" => "1223G0001X", "phone" => "555-0303", "address" => "77 Dental Ave"}
        ]

        data =
          rows
          |> Enum.map(&map_to_row(&1, @headers))
          |> RFC.dump_to_iodata()

        iodata = [Enum.join(@headers, ","), "\n", data]
        File.write!(@preferred_file, iodata)
        :ok
    end
  rescue
    e -> {:error, e}
  end

  @doc "Find a provider by NPI."
  @spec find_by_npi(String.t()) :: {:ok, map()} | {:error, :not_found}
  def find_by_npi(npi) do
    npi = String.trim(npi)

    case pick_file() do
      nil -> {:error, :not_found}
      file ->
        case Enum.find(read_all(file), &(&1["npi"] == npi)) do
          nil -> {:error, :not_found}
          row -> {:ok, row}
        end
    end
  end

  @doc "Case-insensitive substring search over the `name` field."
  @spec search_by_name(String.t()) :: {:ok, [map()]} | {:error, term()}
  def search_by_name(query) do
    q = String.downcase(String.trim(to_string(query)))

    case pick_file() do
      nil -> {:ok, []}
      file ->
        matches =
          read_all(file)
          |> Enum.filter(fn row ->
            String.contains?(String.downcase(Map.get(row, "name", "")), q)
          end)

        {:ok, matches}
    end
  rescue
    e -> {:error, e}
  end

  # ---------------- Internal helpers ----------------

  defp pick_file do
    cond do
      File.exists?(@preferred_file) -> @preferred_file
      File.exists?(@legacy_file)    -> @legacy_file
      true -> nil
    end
  end

  defp read_all(file) do
    file
    |> File.read!()
    |> RFC.parse_string(skip_headers: false)
    |> normalize_rows()
  end

  defp normalize_rows([]), do: []
  defp normalize_rows([headers | rows]) do
    keys = Enum.map(headers, &to_string/1)

    for row <- rows do
      row
      |> Enum.map(&to_string/1)
      |> Enum.zip(keys)
      |> Enum.into(%{}, fn {v, k} -> {k, v} end)
    end
  end

  defp map_to_row(%{} = m, headers) do
    Enum.map(headers, fn h -> Map.get(m, h, "") end)
  end
end
