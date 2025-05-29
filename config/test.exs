import Config

config :meetup_bot, MeetupBot.Repo,
  database: "database/database-test.db",
  pool_size: 5,
  pool: Ecto.Adapters.SQL.Sandbox

config :meetup_bot, :meetup, host: MeetupBot.Meetup.TestHost
config :meetup_bot, :gdg, host: MeetupBot.GDG.TestHost
config :meetup_bot, :luma, host: MeetupBot.Luma.TestHost
config :meetup_bot, Oban, testing: :manual

config :tower, :reporters, [Tower.EphemeralReporter]
