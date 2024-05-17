defmodule MeetupBot.MixProject do
  use Mix.Project

  def project do
    [
      app: :meetup_bot,
      version: "0.1.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
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
      {:req, "~> 0.4.0"},
      {:ecto_sql, "~> 3.11.1"},
      {:ecto_sqlite3, "~> 0.14.0"},
      {:oban, "~> 2.17.8"},
      {:slack_request, "~> 0.1.0"}
    ]
  end
end
