Mix.install([
  {:bandit, ">= 0.0.0"},
  {:ecto_sql, "~> 3.11.1"},
  {:ecto_sqlite3, "~> 0.14"},
  {:oban, "~> 2.8"}
])

Code.require_file("meetup.exs")
Code.require_file("router.exs")
Code.require_file("oban.exs")

defmodule Main do
  def run do
    {:ok, _pid} = Supervisor.start_link([
      MeetupCache,
      {Bandit, plug: Router, scheme: :http, port: 4000},
      Repo,
      {Oban,
        engine: Oban.Engines.Lite,
        repo: Repo,
        plugins: [
          {Oban.Plugins.Cron, crontab: [
            {"@reboot", MeetupCacheWorker},
            {"@hourly", MeetupCacheWorker},
            {PostToSlackWorker.cron(), PostToSlackWorker},
          ]},
          {Oban.Plugins.Pruner, max_age: 300_000}
        ],
        queues: [default: 10]
      }
    ], strategy: :one_for_one)

    Ecto.Migrator.run(Repo, [{0, Migration0}], :up, all: true)
  end
end

Main.run()

# unless running from IEx, sleep idenfinitely so we can serve requests
unless IEx.started?() do
  Process.sleep(:infinity)
end
