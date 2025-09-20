defmodule ProviderVault.Storage do
  alias ProviderVault.Providers.Provider

  @header "npi,name,taxonomy,phone,address\n"

  @doc """
  Initialize CSV if missing.
  Returns:
    :created - file was created now
    :ok      - file already existed
  """
  def init_csv(path) do
    if File.exists?(path) do
      :ok
    else
      File.mkdir_p!(Path.dirname(path))
      File.write!(path, @header)
      :created
    end
  end

  @doc "Clear CSV, leaving only the header."
  def clear_csv(path) do
    File.write!(path, @header)
    :ok
  end

  @doc "Check if an NPI already exists in the CSV."
  def has_npi?(path, npi) do
    stream_csv(path) |> Enum.any?(fn %Provider{npi: existing} -> existing == npi end)
  end

  @doc "Append a provider if its NPI is not present; returns :inserted or :exists."
  def insert_if_missing(path, %Provider{npi: npi} = p) do
    if has_npi?(path, npi) do
      :exists
    else
      append_csv(path, p)
      :inserted
    end
  end

  def append_csv(path, %Provider{} = p) do
    line =
      [p.npi, p.name, p.taxonomy || "", p.phone || "", p.address || ""]
      |> Enum.map(&escape_csv/1)
      |> Enum.join(",")
      |> Kernel.<>("\n")

    File.write(path, line, [:append])
  end

  def stream_csv(path) do
    if File.exists?(path) do
      path
      |> File.stream!()
      # header
      |> Stream.drop(1)
      |> Stream.map(&String.trim_trailing(&1, "\n"))
      |> Stream.reject(&(&1 == ""))
      |> Stream.map(&parse_line/1)
    else
      Stream.map([], fn _ -> nil end)
    end
  end

  defp parse_line(line) do
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

  # Quote only when needed, escape internal quotes by doubling them
  defp escape_csv(nil), do: ""

  defp escape_csv(str) when is_binary(str) do
    needs = String.contains?(str, [",", "\"", "\n", "\r"])
    s = String.replace(str, "\"", "\"\"")
    if needs, do: "\"#{s}\"", else: s
  end

  # Simple CSV splitter that respects double-quoted fields
  defp split_csv_line(line) when is_binary(line) do
    do_split(String.graphemes(line), [], "", false)
  end

  # do_split(chars, fields_acc, current_field, in_quotes?)
  defp do_split([], fields, field, _in_quotes) do
    fields ++ [field]
  end

  defp do_split(["\"" | rest], fields, field, false) do
    # opening quote
    do_split(rest, fields, field, true)
  end

  defp do_split(["\"" | rest], fields, field, true) do
    # could be escaped quote ("")
    case rest do
      ["\"" | rest2] ->
        # escaped double-quote inside quoted field
        do_split(rest2, fields, field <> "\"", true)

      _ ->
        # closing quote
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
