import Config

config :meetup_bot, MeetupBot.Repo, database: "database/database-dev.db"
config :opentelemetry, traces_exporter: :none
# config :opentelemetry, traces_exporter: {:otel_exporter_stdout, []}

config :tower_email, TowerEmail.Mailer, adapter: Swoosh.Adapters.Local
