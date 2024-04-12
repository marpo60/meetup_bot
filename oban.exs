Application.put_env(:my_app, Repo,
  database: "database.db"
)

defmodule Repo do
  use Ecto.Repo, otp_app: :my_app, adapter: Ecto.Adapters.SQLite3
end

defmodule Migration0 do
  use Ecto.Migration

  def change do
    Oban.Migrations.up()
  end
end

defmodule PostToSlackWorker do
  use Oban.Worker

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

defmodule MeetupCacheWorker do
  use Oban.Worker

  @impl true
  def perform(%Oban.Job{}) do
    Meetup.fetch_upcoming_meetups()
    |> MeetupCache.update()

    :ok
  end
end
