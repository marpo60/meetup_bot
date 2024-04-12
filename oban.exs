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

defmodule MeetupCacheWorker do
  use Oban.Worker

  @impl true
  def perform(%Oban.Job{}) do
    Meetup.fetch_upcoming_meetups()
    |> MeetupCache.update()

    :ok
  end
end
