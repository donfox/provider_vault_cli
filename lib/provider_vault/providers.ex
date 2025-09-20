defmodule ProviderVault.Providers do
  defmodule Provider do
    @enforce_keys [:npi, :name]
    defstruct [:npi, :name, :taxonomy, :phone, :address]
  end

  @doc "Format provider for display."
  def format(%Provider{npi: npi, name: name, taxonomy: tax, phone: phone, address: addr}) do
    parts =
      [
        "NPI: #{npi}",
        "Name: #{name}",
        if(tax && tax != "", do: "Taxonomy: #{tax}", else: nil),
        if(phone && phone != "", do: "Phone: #{phone}", else: nil),
        if(addr && addr != "", do: "Address: #{addr}", else: nil)
      ]
      |> Enum.reject(&is_nil/1)

    Enum.join(parts, " | ")
  end
end
