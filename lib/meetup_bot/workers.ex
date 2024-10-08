defmodule MeetupBot.PostToSlackWorker do
  use Oban.Worker

  alias MeetupBot.MeetupCache
  alias MeetupBot.Slack
  alias MeetupBot.Meetup

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
    MeetupCache.values() |> Slack.build_text() |> Slack.post()
    :ok
  end
end

defmodule MeetupBot.MeetupCacheWorker do
  use Oban.Worker

  alias MeetupBot.MeetupCache
  alias MeetupBot.Meetup
  alias MeetupBot.GDG

  @impl true
  def perform(%Oban.Job{}) do
    # Revisit
    datetime_limit = NaiveDateTime.local_now
                     |> NaiveDateTime.add(30 * 24 * 60 * 60, :second)

    (Meetup.fetch_upcoming_meetups() ++ GDG.fetch_live_events())
    |> Enum.filter(& NaiveDateTime.to_date(&1.datetime) !== ~D[2024-10-19])
    |> Enum.concat([%{
      id: "la_meetup",
      name: "LA MEETUP 2024",
      title: "LA MEETUP 2024",
      event_url: "https://www.owu.uy/la-meetup",
      datetime: ~N[2024-10-19 09:00:00],
      end_datetime: ~N[2024-10-19 18:00:00]
    }])
    |> Enum.filter(& NaiveDateTime.compare(&1.datetime, NaiveDateTime.local_now) == :gt)
    |> Enum.filter(& NaiveDateTime.compare(&1.datetime, datetime_limit) == :lt)
    |> Enum.sort_by(& &1.datetime, NaiveDateTime)
    |> MeetupCache.update()

    :ok
  end
end
