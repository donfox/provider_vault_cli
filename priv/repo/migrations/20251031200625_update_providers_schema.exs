defmodule ProviderVault.Repo.Migrations.UpdateProvidersSchema do
  use Ecto.Migration

  def up do
    # Add new columns
    alter table(:providers) do
      add :first_name, :string
      add :last_name, :string
      add :credential, :string
      add :specialty, :string
      add :city, :string
      add :state, :string, size: 2
      add :zip, :string
    end

    # Optionally migrate existing data from 'name' to 'first_name' and 'last_name'
    # This handles names in format "Last, First" or just "Full Name"
    execute """
    UPDATE providers
    SET
      last_name = CASE
        WHEN position(',' in name) > 0
        THEN trim(substring(name from 1 for position(',' in name) - 1))
        ELSE trim(name)
      END,
      first_name = CASE
        WHEN position(',' in name) > 0
        THEN trim(substring(name from position(',' in name) + 1))
        ELSE ''
      END
    WHERE name IS NOT NULL
    """

    # Optionally migrate 'taxonomy' to 'specialty'
    # (You might want to map taxonomy codes to specialty names here)
    execute """
    UPDATE providers
    SET specialty = taxonomy
    WHERE taxonomy IS NOT NULL AND taxonomy != ''
    """

    # Note: We're keeping the old 'name', 'taxonomy', and 'address' columns
    # for now in case you need to reference them. You can drop them later with:
    # alter table(:providers) do
    #   remove :name
    #   remove :taxonomy
    # end
  end

  def down do
    alter table(:providers) do
      remove :first_name
      remove :last_name
      remove :credential
      remove :specialty
      remove :city
      remove :state
      remove :zip
    end
  end
end
