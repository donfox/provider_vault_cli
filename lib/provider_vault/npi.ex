defmodule ProviderVault.Npi do
  @moduledoc """
  Utilities for working with National Provider Identifiers (NPI).

  - `generate/1` builds a valid 10-digit NPI from a 9-digit base.
  - `valid?/1` checks if a 10-digit NPI passes the Luhn algorithm with the 80840 prefix.
  """

  @prefix ~c"80840" |> Enum.map(&(&1 - ?0))

  @doc """
  Generate a valid 10-digit NPI from a 9-digit base string.

  ## Examples
      iex> ProviderVault.Util.Npi.generate("123456789")
      "1234567893"
  """
  def generate(base9) when is_binary(base9) and byte_size(base9) == 9 do
    check = check_digit(base9)
    base9 <> Integer.to_string(check)
  end

  @doc """
  Validate a full 10-digit NPI string.

  ## Examples
      iex> ProviderVault.Util.Npi.valid?("1234567893")
      true

      iex> ProviderVault.Util.Npi.valid?("1234567890")
      false
  """
  def valid?(<<_::binary-size(10)>> = npi) do
    base9 = String.slice(npi, 0, 9)
    String.at(npi, 9) == Integer.to_string(check_digit(base9))
  end

  def valid?(_), do: false

  # --------------------------------------------------------------------------

  defp check_digit(base9) do
    digits =
      @prefix ++ (base9 |> String.to_charlist() |> Enum.map(&(&1 - ?0)))

    sum =
      digits
      |> Enum.reverse()
      |> Enum.with_index()
      |> Enum.reduce(0, fn {d, idx}, acc ->
        if rem(idx, 2) == 0 do
          dd = d * 2
          acc + if dd > 9, do: dd - 9, else: dd
        else
          acc + d
        end
      end)

    rem10 = rem(sum, 10)
    if rem10 == 0, do: 0, else: 10 - rem10
  end
end
