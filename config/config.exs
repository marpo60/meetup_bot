import Config

config :meetup_bot, MeetupBot.Repo, database: "database.db"
config :meetup_bot, ecto_repos: [MeetupBot.Repo]

import_config "#{config_env()}.exs"
