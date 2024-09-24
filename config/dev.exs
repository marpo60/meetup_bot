import Config

config :opentelemetry, traces_exporter: :none
# config :opentelemetry, traces_exporter: {:otel_exporter_stdout, []}

config :tower_email, TowerEmail.Mailer, adapter: Swoosh.Adapters.Local
