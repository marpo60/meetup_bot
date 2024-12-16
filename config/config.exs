import Config

config :meetup_bot, ecto_repos: [MeetupBot.Repo]

config :meetup_bot, :meetup, host: MeetupBot.Meetup.ProdHost
config :meetup_bot, :gdg, host: MeetupBot.GDG.ProdHost

config :elixir, :time_zone_database, Tz.TimeZoneDatabase

config :opentelemetry, sampler: {MeetupBot.Sampler, %{}}

config :tower, :reporters, [Tower.EphemeralReporter, TowerEmail.Reporter]
config :swoosh, :api_client, Swoosh.ApiClient.Req

config :tower_email,
  otp_app: :meetup_bot,
  from: {"Tower", "tower@marpo60.xyz"},
  to: "support@marpo60.xyz"

import_config "#{config_env()}.exs"
