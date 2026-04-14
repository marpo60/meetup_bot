import Config

config :meetup_bot, MeetupBot.Repo, database: "database/database-dev.db"
config :opentelemetry, traces_exporter: :none
# config :opentelemetry, traces_exporter: {:otel_exporter_stdout, []}

config :meetup_bot,
  basic_auth: [
    username: "admin",
    password: "admin"
  ]

config :tower_email, TowerEmail.Mailer, adapter: Swoosh.Adapters.Local
