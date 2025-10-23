defmodule ProviderVault.Repo.Migrations.CreateProviders do
  use Ecto.Migration

  def change do
    create table(:providers) do
      add :npi, :string, size: 10, null: false
      add :name, :string, size: 255, null: false
      add :taxonomy, :string, size: 50
      add :phone, :string, size: 50
      add :address, :text

      timestamps()  # Adds inserted_at and updated_at
    end

    # Indexes for performance
    create unique_index(:providers, [:npi])
    create index(:providers, [:name])
  end
end
