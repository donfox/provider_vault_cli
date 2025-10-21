defmodule ProviderVault.StorageTest do
  use ExUnit.Case
  alias ProviderVault.Storage
  alias ProviderVault.Npi

  @fixture Path.join([__DIR__, "fixtures", "providers_fixture.csv"])

  test "loads providers from fixture CSV" do
    providers = Storage.stream_csv(@fixture) |> Enum.to_list()
    assert length(providers) == 10
    assert %Storage.Provider{name: "Doe, Jane"} = Enum.at(providers, 0)
    assert %Storage.Provider{name: "Taylor, James"} = List.last(providers)
  end

  test "searches providers by partial name" do
    providers = Storage.stream_csv(@fixture) |> Enum.to_list()
    matches = Enum.filter(providers, fn p -> String.contains?(p.name, "Smith") end)
    assert Enum.any?(matches, &(&1.name == "Smith, John"))
  end

  test "validates NPI numbers from fixture" do
    providers = Storage.stream_csv(@fixture) |> Enum.to_list()

    Enum.each(Enum.take(providers, 3), fn p ->
      assert Npi.valid?(p.npi)
    end)
  end
end
