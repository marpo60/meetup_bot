import Config

config :meetup_bot, MeetupBot.Repo, database: "database.db"
config :meetup_bot, ecto_repos: [MeetupBot.Repo]

config :opentelemetry, sampler: {MeetupBot.Sampler, %{}}
import_config "#{config_env()}.exs"
