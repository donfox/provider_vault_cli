# lib/provider_vault/csv.ex
defmodule ProviderVault.CSV do
  defdelegate dump_to_iodata(rows), to: NimbleCSV.RFC4180, as: :dump_to_iodata
  defdelegate parse_string(bin), to: NimbleCSV.RFC4180, as: :parse_string
end
