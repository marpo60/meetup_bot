defmodule MeetupBot.PostMessagesWorker do
  use Oban.Worker

  require OpenTelemetry.Tracer

  alias MeetupBot.MeetupCache
  alias MeetupBot.Slack
  alias MeetupBot.Telegram
  alias OpenTelemetry.Tracer

  def cron do
    case System.get_env("TARGET") do
      nil -> "* * * * *"
      "local" -> "* * * * *"
      "staging" -> "0 * * * 1-5"
      "production" -> "0 13 * * 1"
    end
  end

  @impl true
  def perform(%Oban.Job{}) do
    Tracer.with_span "oban.perform" do
      Tracer.set_attributes([{:worker, "PostMessagesWorker"}])

      meetups = MeetupCache.values()

      Slack.build_text(meetups) |> Slack.post()
      Telegram.build_text(meetups) |> Telegram.post()

      :ok
    end
  end
end
