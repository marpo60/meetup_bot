defmodule MeetupBot.SyncManualEventsWorker do
  use Oban.Worker

  require OpenTelemetry.Tracer

  alias MeetupBot.MeetupCache
  alias MeetupBot.Meetup
  alias MeetupBot.GDG
  alias OpenTelemetry.Tracer

  @impl true
  def perform(%Oban.Job{}) do
    Tracer.with_span "oban.perform" do
      Tracer.set_attributes([{:worker, "SyncManualEventsWorker"}])

      MeetupCache.sync_manual(events())

      :ok
    end
  end

  defp events() do
    [
      %{
        source: "manual",
        source_id: "1",
        name: "OWU Code Pop",
        title: "OWU Code Pop",
        event_url: "http://example.com",
        datetime: ~N[2025-04-05 09:00:00],
        end_datetime: ~N[2025-04-05 18:00:00]
      }
    ]
  end
end
