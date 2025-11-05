defmodule ProviderVault.DataSources.MockProviderB do
  @moduledoc """
  Mock provider data source B - Surgical Specialists Network
  Simulates a surgical specialists network with orthopedics,
  cardiothoracic surgery, and neurosurgery.
  """

  require Logger

  @source_name "Mock-SurgicalSpec"

  @specialties [
    "Orthopedic Surgery",
    "Cardiothoracic Surgery",
    "Neurosurgery",
    "General Surgery",
    "Vascular Surgery"
  ]

  @cities_states [
    {"Chicago", "IL"},
    {"Milwaukee", "WI"},
    {"Minneapolis", "MN"},
    {"Detroit", "MI"}
  ]

  @first_names ~w(Christopher Jessica Daniel Nancy Matthew Karen Joseph Betty)
  @last_names ~w(Wilson White Harris Clark Lewis Robinson Walker Young)
  @credentials ~w(MD DO)

  @doc """
  Fetches mock provider data from Surgical Specialists Network.
  Returns {:ok, providers} or {:error, reason}.
  """
  def fetch do
    Logger.info("[#{@source_name}] Starting fetch...")
    start_time = System.monotonic_time(:millisecond)

    # Simulate network latency
    Process.sleep(400 + :rand.uniform(500))

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
        npi: "30000000#{String.pad_leading(to_string(i), 2, "0")}",
        first_name: Enum.random(@first_names),
        last_name: Enum.random(@last_names),
        credential: Enum.random(@credentials),
        specialty: Enum.random(@specialties),
        address: "#{300 + i} Surgery Center Dr, Floor #{i}",
        city: city,
        state: state,
        zip: generate_zip(state, i),
        phone: "(312) #{String.pad_leading(to_string(300 + i), 3, "0")}-0000",
        source: @source_name
      }
    end)
  end

  defp generate_zip("IL", i), do: "606#{String.pad_leading(to_string(i), 2, "0")}"
  defp generate_zip("WI", i), do: "532#{String.pad_leading(to_string(i), 2, "0")}"
  defp generate_zip("MN", i), do: "554#{String.pad_leading(to_string(i), 2, "0")}"
  defp generate_zip("MI", i), do: "482#{String.pad_leading(to_string(i), 2, "0")}"
  defp generate_zip(_, i), do: "000#{String.pad_leading(to_string(i), 2, "0")}"
end
