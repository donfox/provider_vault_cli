defmodule ProviderVault.Validators do
  alias Mix.Shell.IO, as: Shell

  @doc """
  Validate NPI: must be 10 digits and pass Luhn check.
  NPI check digit is computed with Luhn mod-10 using the prefix '80840' + first 9 digits.
  """
  def require_npi(npi) do
    npi = String.replace(npi, ~r/\D/, "")

    cond do
      String.length(npi) != 10 ->
        Shell.error("NPI must be 10 digits")
        Shell.prompt("NPI (10 digits): ") |> String.trim() |> require_npi()

      not luhn_valid_npi?(npi) ->
        Shell.error("Invalid NPI check digit")
        Shell.prompt("NPI (10 digits): ") |> String.trim() |> require_npi()

      true ->
        npi
    end
  end

  defp luhn_valid_npi?(npi10) do
    # Per NPPES: use Luhn on prefix '80840' plus first 9 digits; compare with 10th digit
    {body9, check_digit} = String.split_at(npi10, 9)
    digits = ~c"80840" |> Enum.map(&(&1 - ?0))
    digits = digits ++ (body9 |> String.to_charlist() |> Enum.map(&(&1 - ?0)))

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

    expected = rem(10 - rem(sum, 10), 10)
    Integer.to_string(expected) == check_digit
  end

  @doc """
  Require a non-empty string; re-prompts on empty.
  """
  def require_nonempty(value, message) do
    if String.trim(value) == "" do
      Shell.error(message)
      Shell.prompt("> ") |> String.trim() |> require_nonempty(message)
    else
      value
    end
  end
end
