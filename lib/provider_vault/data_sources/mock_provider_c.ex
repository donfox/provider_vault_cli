defmodule ProviderVault.DataSources.MockProviderC do
  @moduledoc """
  Mock provider data source C - Mental Health & Specialty Care

  Simulates a mental health and specialty care network with psychiatrists,
  psychologists, and other behavioral health specialists.
  """

  require Logger

  @source_name "Mock-MentalHealth"

  @specialties [
    "Psychiatry",
    "Clinical Psychology",
    "Counseling",
    "Behavioral Health",
    "Addiction Medicine"
  ]

  @cities_states [
    {"Seattle", "WA"},
    {"Portland", "OR"},
    {"San Francisco", "CA"},
    {"Sacramento", "CA"}
  ]

  @first_names ~w(Sarah David Jennifer Brian Amanda Kevin Lisa Ryan)
  @last_names ~w(Hall Allen Young King Wright Lopez Hill Scott)
  @credentials ~w(MD DO PsyD PhD LCSW)

  @doc """
  Fetches mock provider data from Mental Health & Specialty Care Network.
  Returns {:ok, providers} or {:error, reason}.
  """
  def fetch do
    Logger.info("[#{@source_name}] Starting fetch...")
    start_time = System.monotonic_time(:millisecond)

    # Simulate network latency
    Process.sleep(350 + :rand.uniform(450))

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
        npi: "40000000#{String.pad_leading(to_string(i), 2, "0")}",
        first_name: Enum.random(@first_names),
        last_name: Enum.random(@last_names),
        credential: Enum.random(@credentials),
        specialty: Enum.random(@specialties),
        address: "#{400 + i} Mental Health Way, Suite #{200 + i}",
        city: city,
        state: state,
        zip: generate_zip(state, i),
        phone: "(206) #{String.pad_leading(to_string(400 + i), 3, "0")}-0000",
        source: @source_name
      }
    end)
  end

  defp generate_zip("WA", i), do: "981#{String.pad_leading(to_string(i), 2, "0")}"
  defp generate_zip("OR", i), do: "972#{String.pad_leading(to_string(i), 2, "0")}"
  defp generate_zip("CA", i), do: "941#{String.pad_leading(to_string(i), 2, "0")}"
  defp generate_zip(_, i), do: "000#{String.pad_leading(to_string(i), 2, "0")}"
end
