defmodule ProviderVault.Excel.Convert do
  @moduledoc """
  Excel → CSV conversion using `xlsxir`.

  ### Responsibilities
  - Extract a worksheet (by index or name) and write a CSV to `priv/data/`.
  - Surface friendly errors for invalid file type, bad sheet index, etc.

  ### Deprecations
  Elixir ≥ 1.14: prefer `~c""` for charlists and modern child specs.
  """

  alias ProviderVault.CSV

  @type sheet_opt :: pos_integer() | String.t()
  @type opts :: [sheet: sheet_opt, out_dir: String.t()]

  @spec convert_file(String.t(), opts) ::
          {:ok, String.t()} | {:error, term()}
  @doc """
  Convert a single .xlsx file to CSV.

      iex> ProviderVault.Excel.Convert.convert_file("priv/data/file.xlsx")
      {:ok, "priv/data/file.csv"}
  """
  def convert_file(xlsx_path, opts \\ []) when is_binary(xlsx_path) do
    if !String.ends_with?(String.downcase(xlsx_path), ".xlsx") do
      {:error, {:invalid_file, "expected .xlsx"}}
    else
      # 1-based by default
      sheet = Keyword.get(opts, :sheet, 1)
      out_dir = Keyword.get(opts, :out_dir, default_data_dir())

      with :ok <- ensure_out_dir(out_dir),
           {:ok, rows} <- extract_rows(xlsx_path, sheet),
           {:ok, csv_iodata} <- to_csv(rows) do
        base = xlsx_path |> Path.basename() |> Path.rootname()
        out_path = Path.join(out_dir, base <> ".csv")

        case File.write(out_path, csv_iodata) do
          :ok -> {:ok, out_path}
          {:error, reason} -> {:error, {:write_failed, reason}}
        end
      end
    end
  end

  @spec convert_all(String.t(), opts) :: [{String.t(), {:ok, String.t()} | {:error, term()}}]
  @doc """
  Convert all `.xlsx` files inside a directory (non-recursive).
  Returns a list of `{path, result}` tuples.
  """
  def convert_all(dir, opts \\ []) when is_binary(dir) do
    sheet = Keyword.get(opts, :sheet, 1)
    out_dir = Keyword.get(opts, :out_dir, default_data_dir())

    case ensure_out_dir(out_dir) do
      :ok ->
        dir
        |> File.ls!()
        |> Enum.filter(&String.ends_with?(String.downcase(&1), ".xlsx"))
        |> Enum.map(fn f ->
          path = Path.join(dir, f)
          {path, convert_file(path, sheet: sheet, out_dir: out_dir)}
        end)

      {:error, reason} ->
        # propagate the directory error for each file attempt
        [{dir, {:error, {:mkdir_failed, reason}}}]
    end
  end

  # --- Internals -------------------------------------------------------------

  # Supports 1-based sheet index OR sheet name
  defp extract_rows(xlsx_path, sheet) when is_integer(sheet) and sheet > 0 do
    case Xlsxir.extract(xlsx_path, sheet) do
      {:ok, tid} ->
        try do
          {:ok, normalize_rows(Xlsxir.get_list(tid))}
        after
          Xlsxir.close(tid)
        end

      {:error, reason} ->
        {:error, {:extract_failed, reason}}
    end
  end

  defp extract_rows(xlsx_path, sheet_name) when is_binary(sheet_name) do
    case Xlsxir.extract(xlsx_path, sheet_name) do
      {:ok, tid} ->
        try do
          {:ok, normalize_rows(Xlsxir.get_list(tid))}
        after
          Xlsxir.close(tid)
        end

      {:error, reason} ->
        {:error, {:extract_failed, reason}}
    end
  end

  defp to_csv(rows) when is_list(rows) do
    try do
      {:ok, CSV.dump_to_iodata(rows)}
    rescue
      e -> {:error, {:csv_encode_failed, e}}
    end
  end

  defp ensure_out_dir(dir) do
    case File.mkdir_p(dir) do
      :ok -> :ok
      {:error, reason} -> {:error, {:mkdir_failed, reason}}
    end
  end

  # Prefer priv/data as the default output bucket
  defp default_data_dir do
    case :code.priv_dir(:provider_vault_cli) do
      dir when is_list(dir) ->
        Path.join(List.to_string(dir), "data")

      {:error, _} ->
        Path.join(File.cwd!(), "priv/data")

      other ->
        other |> to_string() |> then(&Path.join(&1, "data"))
    end
  end

  # Normalize cells to strings for CSV
  defp normalize_rows(rows) do
    Enum.map(rows, fn row ->
      row
      |> List.wrap()
      |> Enum.map(&to_cell/1)
    end)
  end

  defp to_cell(nil), do: ""
  defp to_cell(%Date{} = d), do: Date.to_iso8601(d)
  defp to_cell(%NaiveDateTime{} = dt), do: NaiveDateTime.to_iso8601(dt)
  defp to_cell(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp to_cell(num) when is_integer(num) or is_float(num), do: to_string(num)
  defp to_cell(other) when is_binary(other), do: other
  defp to_cell(other), do: inspect(other)
end
