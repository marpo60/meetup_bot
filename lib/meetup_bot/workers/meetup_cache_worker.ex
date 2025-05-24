defmodule MeetupBot.MeetupCacheWorker do
  use Oban.Worker

  require OpenTelemetry.Tracer

  alias MeetupBot.MeetupCache
  alias MeetupBot.Meetup
  alias MeetupBot.Constants
  alias OpenTelemetry.Tracer

  @impl true
  def perform(%Oban.Job{}) do
    Tracer.with_span "oban.perform" do
      Tracer.set_attributes([{:worker, "MeetupCacheWorker"}])

      meetup_events = Meetup.fetch_upcoming_meetups()
      MeetupCache.sync_upcoming_external_events(meetup_events, Constants.meetup_source())

      :ok
    end
  end
end
