import Config

config :meetup_bot, MeetupBot.Repo,
  database: "database/database-test.db",
  pool_size: 5,
  pool: Ecto.Adapters.SQL.Sandbox
