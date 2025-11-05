defmodule ProviderVault.Provider do
  use Ecto.Schema
  import Ecto.Changeset

  schema "providers" do
    # New standardized fields
    field(:npi, :string)
    field(:first_name, :string)
    field(:last_name, :string)
    field(:credential, :string)
    field(:specialty, :string)
    field(:address, :string)
    field(:city, :string)
    field(:state, :string)
    field(:zip, :string)
    field(:phone, :string)

    # Legacy fields (kept for backward compatibility)
    # These can be removed after full migration
    field(:name, :string)
    field(:taxonomy, :string)

    timestamps()
  end

  @doc """
  Validates provider data before inserting/updating.
  """
  def changeset(provider, attrs) do
    provider
    |> cast(attrs, [
      :npi,
      :first_name,
      :last_name,
      :credential,
      :specialty,
      :address,
      :city,
      :state,
      :zip,
      :phone,
      # Legacy fields
      :name,
      :taxonomy
    ])
    |> validate_required([:npi])
    |> validate_length(:npi, is: 10)
    |> validate_format(:npi, ~r/^\d{10}$/)
    |> validate_length(:state, is: 2)
    |> unique_constraint(:npi)
    |> maybe_build_full_name()
  end

  # Helper to build 'name' field from first_name and last_name for backward compatibility
  defp maybe_build_full_name(changeset) do
    first = get_change(changeset, :first_name)
    last = get_change(changeset, :last_name)

    case {first, last} do
      {nil, nil} -> changeset
      {f, nil} -> put_change(changeset, :name, f)
      {nil, l} -> put_change(changeset, :name, l)
      {f, l} -> put_change(changeset, :name, "#{l}, #{f}")
    end
  end
end
