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

      gdg_events = GDG.fetch_live_events()
      MeetupCache.sync_upcoming_external_events(gdg_events, Event.gdg_source())

      :ok
    end
  end
end
