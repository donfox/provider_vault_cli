defmodule ProviderVault.DataSources.MockProviderA do
  @moduledoc """
  Mock provider data source A - Primary Care Network

  Simulates a primary care provider network with family medicine,
  internal medicine, and pediatrics specialists.
  """

  require Logger

  @source_name "Mock-PrimaryCare"

  @specialties [
    "Family Medicine",
    "Internal Medicine",
    "Pediatrics",
    "General Practice"
  ]

  @cities_states [
    {"Boston", "MA"},
    {"Providence", "RI"},
    {"Portland", "ME"},
    {"Burlington", "VT"}
  ]

  @first_names ~w(James Mary Robert Patricia Michael Linda William Barbara)
  @last_names ~w(Anderson Taylor Thomas Moore Jackson Martin Lee Thompson)
  @credentials ~w(MD DO)

  @doc """
  Fetches mock provider data from Primary Care Network.
  Returns {:ok, providers} or {:error, reason}.
  """
  def fetch do
    Logger.info("[#{@source_name}] Starting fetch...")
    start_time = System.monotonic_time(:millisecond)

    # Simulate network latency
    Process.sleep(300 + :rand.uniform(400))

    providers = generate_providers()

    elapsed = System.monotonic_time(:millisecond) - start_time
    Logger.info("[#{@source_name}] Fetched #{length(providers)} providers in #{elapsed}ms")

    {:ok, providers}
  end

  defp generate_providers do
    1..15
    |> Enum.map(fn i ->
      {city, state} = Enum.random(@cities_states)

      %{
        npi: "20000000#{String.pad_leading(to_string(i), 2, "0")}",
        first_name: Enum.random(@first_names),
        last_name: Enum.random(@last_names),
        credential: Enum.random(@credentials),
        specialty: Enum.random(@specialties),
        address: "#{200 + i} Primary Care Blvd, Suite #{100 + i}",
        city: city,
        state: state,
        zip: generate_zip(state, i),
        phone: "(617) #{String.pad_leading(to_string(200 + i), 3, "0")}-0000",
        source: @source_name
      }
    end)
  end

  defp generate_zip("MA", i), do: "021#{String.pad_leading(to_string(i), 2, "0")}"
  defp generate_zip("RI", i), do: "029#{String.pad_leading(to_string(i), 2, "0")}"
  defp generate_zip("ME", i), do: "041#{String.pad_leading(to_string(i), 2, "0")}"
  defp generate_zip("VT", i), do: "054#{String.pad_leading(to_string(i), 2, "0")}"
  defp generate_zip(_, i), do: "000#{String.pad_leading(to_string(i), 2, "0")}"
end
