defmodule MeetupBot.LumaCacheWorker do
  use Oban.Worker, max_attempts: 2

  require OpenTelemetry.Tracer

  alias MeetupBot.MeetupCache
  alias MeetupBot.Event
  alias MeetupBot.Luma
  alias OpenTelemetry.Tracer

  @impl true
  def perform(%Oban.Job{}) do
    Tracer.with_span "oban.perform" do
      Tracer.set_attributes([{:worker, "LumaCacheWorker"}])

      events = Luma.fetch_upcoming_meetups()

      MeetupCache.sync(Event.luma_source(), events)

      :ok
    end
  end
end
