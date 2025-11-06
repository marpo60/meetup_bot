defmodule MeetupBot.MixProject do
  use Mix.Project

  def project do
    [
      app: :meetup_bot,
      version: "0.1.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      releases: [
        meetup_bot: [
          applications: [
            opentelemetry_exporter: :permanent,
            opentelemetry: :temporary
          ]
        ]
      ],
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {MeetupBot.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:bandit, "~> 1.6.0"},
      {:req, "~> 0.5.10"},
      {:ecto_sql, "~> 3.12.0"},
      {:ecto_sqlite3, "~> 0.17.2"},
      # https://github.com/elixir-sqlite/exqlite/issues/323
      {:exqlite, "~> 0.29.0"},
      {:slack_request, "~> 1.0"},
      {:oban, "~> 2.18.2"},
      {:tower_email, "~> 0.6.0"},
      {:tz, "~> 0.28"},
      {:opentelemetry, "~> 1.3"},
      {:opentelemetry_api, "~> 1.2"},
      {:opentelemetry_bandit, "~> 0.2.0-a"},
      {:opentelemetry_exporter, "~> 1.6"},
      {:opentelemetry_req, "~> 1.0.0-beta.1"},
      {:opentelemetry_ecto, "~> 1.0"},
      {:test_server, "~> 0.1.21", only: :test},
      {:mox, "~> 1.0", only: :test}
    ]
  end
end
