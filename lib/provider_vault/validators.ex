defmodule ProviderVault.Validators do
  @moduledoc """
  Pure validation functions.
  All functions return {:ok, value} or {:error, reason}.
  """

  alias ProviderVault.Npi

  @doc "Validate NPI: must be 10 digits and pass the Luhn check."
  @spec validate_npi(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def validate_npi(npi) when is_binary(npi) do
    n = String.replace(npi, ~r/\D/, "")

    cond do
      String.length(n) != 10 ->
        {:error, "NPI must be 10 digits"}

      not Npi.valid?(n) ->
        {:error, "Invalid NPI check digit"}

      true ->
        {:ok, n}
    end
  end

  @doc "Validate non-empty string."
  @spec validate_nonempty(String.t()) :: {:ok, String.t()} | {:error, :empty}
  def validate_nonempty(value) when is_binary(value) do
    trimmed = String.trim(value)

    if trimmed == "" do
      {:error, :empty}
    else
      {:ok, trimmed}
    end
  end

  @doc "Validate phone number format (basic check)."
  @spec validate_phone(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def validate_phone(phone) when is_binary(phone) do
    # Remove all non-digits
    digits = String.replace(phone, ~r/\D/, "")

    cond do
      String.length(digits) < 10 ->
        {:error, "Phone number must have at least 10 digits"}

      String.length(digits) > 11 ->
        {:error, "Phone number has too many digits"}

      true ->
        {:ok, phone}
    end
  end
end
