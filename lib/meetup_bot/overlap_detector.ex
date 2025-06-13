defmodule MeetupBot.OverlapDetector do
  use GenServer

  require Logger

  alias MeetupBot.MeetupCache

  # Client
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  def check(pid) do
    send(pid, :check)
  end

  # Server
  @impl true
  def init(_init_arg) do
    Process.set_label(:overlap_detector)
    schedule_check()
    {:ok, get_overlapping_upcoming_events()}
  end

  @impl true
  def handle_info(:check, previous_overlaps) do
    overlaps = get_overlapping_upcoming_events()

    # This check difference is as simple as possible
    # we are not getting all the overlap group together
    new_overlaps =
      Enum.reject(overlaps, fn [a, b] ->
        [a, b] in previous_overlaps
      end)

    notify(new_overlaps)

    schedule_check()

    {:noreply, overlaps}
  end

  defp schedule_check() do
    Process.send_after(self(), :check, :timer.minutes(5))
  end

  defp get_overlapping_upcoming_events() do
    MeetupCache.overlapping_upcoming_events()
  end

  # Notify via a critical log
  # Move this into Slack and a proper channel
  # meetup organizers maybe?
  defp notify(overlaps) do
    overlaps
    |> Enum.each(fn [a, b] ->
      Logger.critical("""
        New Overlap
        #{a.id} - #{a.name} - #{a.datetime}
        #{b.id} - #{b.name} - #{b.datetime}
      """)
    end)
  end
end
