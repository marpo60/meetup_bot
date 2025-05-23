defmodule MeetupBot.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    OpentelemetryEcto.setup([:meetup_bot, :repo], db_statement: :enabled)
    OpentelemetryBandit.setup()

    Tower.attach()

    MeetupBot.Release.migrate()

    children = [
      {Bandit, plug: MeetupBot.Router, scheme: :http, port: 4000},
      MeetupBot.Repo,
      {Oban,
       engine: Oban.Engines.Lite,
       repo: MeetupBot.Repo,
       plugins: [
         {Oban.Plugins.Cron,
          crontab: [
            {"@reboot", MeetupBot.SyncManualEventsWorker},
            {"@hourly", MeetupBot.MeetupCacheWorker},
            {"@hourly", MeetupBot.GDGCacheWorker},
            {"0 8 * * *", MeetupBot.BackupDatabaseWorker},
            {MeetupBot.PostToSlackWorker.cron(), MeetupBot.PostToSlackWorker}
          ]},
         {Oban.Plugins.Pruner, max_age: 300_000}
       ],
       queues: [default: 10]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: MeetupBot.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
