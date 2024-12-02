defmodule MeetupBot.MeetupCacheWorker do
  use Oban.Worker

  require OpenTelemetry.Tracer

  alias MeetupBot.MeetupCache
  alias MeetupBot.Meetup
  alias MeetupBot.GDG
  alias OpenTelemetry.Tracer

  @impl true
  def perform(%Oban.Job{}) do
    Tracer.with_span "oban.perform" do
      Tracer.set_attributes([{:worker, "MeetupCacheWorker"}])

      (Meetup.fetch_upcoming_meetups() ++ GDG.fetch_live_events())
      |> MeetupCache.update()

      :ok
    end
  end
end
