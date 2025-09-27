defmodule ProviderVault.Validators do
  @moduledoc false

  # NPI uses Luhn mod-10 on the prefix "80840" + first 9 digits.
  @prefix_digits ~c"80840" |> Enum.map(&(&1 - ?0))

  @doc """
  Validate NPI: must be 10 digits and pass the NPI Luhn check.
  If invalid, prints an error and re-prompts from STDIN.
  """
  @spec require_npi(String.t()) :: String.t()
  def require_npi(npi) when is_binary(npi) do
    n = String.replace(npi, ~r/\D/, "")

    cond do
      String.length(n) != 10 ->
        IO.puts(:stderr, "NPI must be 10 digits")
        prompt_retry_npi()

      not luhn_valid_npi?(n) ->
        IO.puts(:stderr, "Invalid NPI check digit")
        prompt_retry_npi()

      true ->
        n
    end
  end

  defp prompt_retry_npi do
    case IO.gets("NPI (10 digits): ") do
      :eof -> raise ArgumentError, "no input"
      nil -> raise ArgumentError, "no input"
      s -> require_npi(String.trim(s))
    end
  end

  @doc """
  Require a non-empty string; on empty, prints the message and re-prompts.
  """
  @spec require_nonempty(String.t(), String.t()) :: String.t()
  def require_nonempty(value, message) when is_binary(value) and is_binary(message) do
    if String.trim(value) == "" do
      IO.puts(:stderr, message)

      case IO.gets("> ") do
        :eof -> raise ArgumentError, "no input"
        nil -> raise ArgumentError, "no input"
        s -> require_nonempty(String.trim(s), message)
      end
    else
      value
    end
  end

  # --- Luhn for NPI (prefix "80840" + body9) ----------------------------------

  @spec luhn_valid_npi?(String.t()) :: boolean()
  defp luhn_valid_npi?(<<_::binary-size(10)>> = npi10) do
    {body9, check_digit} = String.split_at(npi10, 9)

    digits =
      @prefix_digits ++
        (body9 |> String.to_charlist() |> Enum.map(&(&1 - ?0)))

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

  defp luhn_valid_npi?(_), do: false
end
