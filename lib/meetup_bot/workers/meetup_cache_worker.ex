defmodule MeetupBot.MeetupCacheWorker do
  use Oban.Worker, max_attempts: 2

  require OpenTelemetry.Tracer

  alias MeetupBot.MeetupCache
  alias MeetupBot.Meetup
  alias MeetupBot.Event
  alias OpenTelemetry.Tracer

  @impl true
  def perform(%Oban.Job{}) do
    Tracer.with_span "oban.perform" do
      Tracer.set_attributes([{:worker, "MeetupCacheWorker"}])

      events = Meetup.fetch_upcoming_meetups()

      MeetupCache.sync(Event.meetup_source(), events)

      :ok
    end
  end
end
