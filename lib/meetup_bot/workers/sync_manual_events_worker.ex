defmodule MeetupBot.SyncManualEventsWorker do
  use Oban.Worker

  require OpenTelemetry.Tracer

  alias MeetupBot.MeetupCache
  alias OpenTelemetry.Tracer

  @impl true
  def perform(%Oban.Job{}) do
    Tracer.with_span "oban.perform" do
      Tracer.set_attributes([{:worker, "SyncManualEventsWorker"}])

      events = events()
      MeetupCache.update_or_create(events)
      MeetupCache.delete_events_not_present_in_source("manual", events)

      :ok
    end
  end

  defp events() do
    [
      %{
        source: "manual",
        source_id: "0",
        name: "Name",
        title: "Title",
        event_url: "https://example.com",
        datetime: ~N[2020-01-01 18:00:00],
        end_datetime: ~N[2020-01-01 19:00:00]
      },
      %{
        source: "manual",
        source_id: "1",
        name: "MujeresIT",
        title: "Conversatorio de Mujeres Online - Previa del 8M",
        event_url: "https://us06web.zoom.us/meeting/register/OE6XscvQTYyx50TIVgKrXw",
        datetime: ~N[2025-03-07 18:30:00],
        end_datetime: ~N[2025-03-07 19:30:00]
      }
    ]
  end
end
