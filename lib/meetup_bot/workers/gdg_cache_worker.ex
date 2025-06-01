defmodule MeetupBot.GDGCacheWorker do
  use Oban.Worker

  require OpenTelemetry.Tracer

  alias MeetupBot.MeetupCache
  alias MeetupBot.Event
  alias MeetupBot.GDG
  alias OpenTelemetry.Tracer

  @impl true
  def perform(%Oban.Job{}) do
    Tracer.with_span "oban.perform" do
      Tracer.set_attributes([{:worker, "GDGCacheWorker"}])

      events = GDG.fetch_live_events()

      MeetupCache.update_or_create(events)
      MeetupCache.delete_events_not_present_in_source(Event.gdg_source(), events)

      :ok
    end
  end
end
