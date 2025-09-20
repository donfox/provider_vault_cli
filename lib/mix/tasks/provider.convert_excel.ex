defmodule Mix.Tasks.Provider.ConvertExcel do
  use Mix.Task
  @shortdoc "Convert .xlsx files to CSV into ./data (file or directory)"
  @moduledoc """
  Convert Excel `.xlsx` file(s) to CSV stored in the project's `data/` directory by default.

  ## Usage

      mix provider.convert_excel path/to/file.xlsx
      mix provider.convert_excel path/to/dir --sheet 0 --out data

  Options:
    * `--sheet` - zero-based sheet index to extract (default: 0)
    * `--out`   - output directory (default: ./data)
  """

  @impl true
  def run(args) do
    Mix.Task.run("app.start")

    {opts, paths, _} =
      OptionParser.parse(args,
        switches: [sheet: :integer, out: :string],
        aliases: [s: :sheet, o: :out]
      )

    sheet = Keyword.get(opts, :sheet, 0)
    out_dir = Keyword.get(opts, :out, Path.join(File.cwd!(), "data"))

    case paths do
      [single] -> handle_path(single, sheet, out_dir)
      _ -> Mix.shell().error("Please provide a file or a directory path.")
    end
  end

  defp handle_path(path, sheet, out_dir) do
    if File.dir?(path) do
      results = ProviderVault.Excel.Convert.convert_all(path, sheet: sheet, out_dir: out_dir)

      Enum.each(results, fn {p, res} ->
        case res do
          {:ok, out} -> Mix.shell().info("OK  #{p} -> #{out}")
          {:error, reason} -> Mix.shell().error("ERR #{p} -> #{inspect(reason)}")
        end
      end)
    else
      case ProviderVault.Excel.Convert.convert_file(path, sheet: sheet, out_dir: out_dir) do
        {:ok, out} -> Mix.shell().info("OK  #{path} -> #{out}")
        {:error, reason} -> Mix.shell().error("ERR #{path} -> #{inspect(reason)}")
      end
    end
  end
end
