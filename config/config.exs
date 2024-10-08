import Config

config :meetup_bot, MeetupBot.Repo, database: "database.db"
config :meetup_bot, ecto_repos: [MeetupBot.Repo]

config :opentelemetry, sampler: {MeetupBot.Sampler, %{}}

config :tower, :reporters,  [Tower.EphemeralReporter, TowerEmail.Reporter]
config :swoosh, :api_client, Swoosh.ApiClient.Req

config :tower_email,
  otp_app: :meetup_bot,
  from: {"Tower", "tower@marpo60.xyz"},
  to: "support@marpo60.xyz"

import_config "#{config_env()}.exs"
