defmodule ProviderVault.Util.NpiTest do
  use ExUnit.Case, async: true
  alias ProviderVault.Util.Npi

  test "generate produces valid NPIs" do
    assert Npi.generate("123456789") == "1234567893"
    assert Npi.generate("234567890") == "2345678900"
  end

  test "valid? recognizes correct NPIs" do
    assert Npi.valid?("1234567893")
    assert Npi.valid?("2345678900")
    refute Npi.valid?("1234567890")
    refute Npi.valid?("2345678901")
    refute Npi.valid?("abcdefghi0")
  end
end
