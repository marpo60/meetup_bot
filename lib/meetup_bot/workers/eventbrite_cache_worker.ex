defmodule MeetupBot.EventbriteCacheWorker do
  use Oban.Worker, max_attempts: 2

  require OpenTelemetry.Tracer

  alias MeetupBot.MeetupCache
  alias MeetupBot.Event
  alias MeetupBot.Eventbrite
  alias OpenTelemetry.Tracer

  @impl true
  def perform(%Oban.Job{}) do
    Tracer.with_span "oban.perform" do
      Tracer.set_attributes([{:worker, "EventbriteCacheWorker"}])

      events = Eventbrite.fetch_upcoming_meetups()

      MeetupCache.sync(Event.eventbrite_source(), events)

      :ok
    end
  end
end
