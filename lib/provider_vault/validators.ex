defmodule ProviderVault.Validators do
  @moduledoc false

  alias ProviderVault.Npi

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

      not Npi.valid?(n) ->
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
end
