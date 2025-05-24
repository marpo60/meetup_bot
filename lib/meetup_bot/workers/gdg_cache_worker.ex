defmodule MeetupBot.GDGCacheWorker do
  use Oban.Worker

  require OpenTelemetry.Tracer

  alias MeetupBot.MeetupCache
  alias MeetupBot.GDG
  alias MeetupBot.Constants
  alias OpenTelemetry.Tracer

  @impl true
  def perform(%Oban.Job{}) do
    Tracer.with_span "oban.perform" do
      Tracer.set_attributes([{:worker, "GDGCacheWorker"}])

      gdg_events = GDG.fetch_live_events()
      MeetupCache.sync_upcoming_external_events(gdg_events, Constants.gdg_source())

      :ok
    end
  end
end
