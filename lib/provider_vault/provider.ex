defmodule ProviderVault.Provider do
  use Ecto.Schema
  import Ecto.Changeset

  schema "providers" do
    field(:npi, :string)
    field(:name, :string)
    field(:taxonomy, :string)
    field(:phone, :string)
    field(:address, :string)

    timestamps()
  end

  @doc """
  Validates provider data before inserting/updating.
  """
  def changeset(provider, attrs) do
    provider
    |> cast(attrs, [:npi, :name, :taxonomy, :phone, :address])
    |> validate_required([:npi, :name])
    |> validate_length(:npi, is: 10)
    |> validate_format(:npi, ~r/^\d{10}$/)
    |> unique_constraint(:npi)
  end
end
