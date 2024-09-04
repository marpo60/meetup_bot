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
      {:bandit, "~> 1.4.2"},
      {:req, "~> 0.5.6"},
      {:ecto_sql, "~> 3.11.1"},
      {:ecto_sqlite3, "~> 0.14.0"},
      {:slack_request, "~> 0.3.1"},
      {:oban, "~> 2.17.8"},
      {:opentelemetry, "~> 1.3"},
      {:opentelemetry_api, "~> 1.2"},
      {:opentelemetry_exporter, "~> 1.6"},
      {:opentelemetry_oban, "~> 1.0"},
      {:opentelemetry_req, "~> 0.2.0"},
      {:opentelemetry_ecto, "~> 1.0"}
    ]
  end
end
