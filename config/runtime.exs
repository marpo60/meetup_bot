import Config

config :tower_email,
  environment: System.get_env("TARGET", to_string(config_env()))

if config_env() == :prod do
  config :tower_email, TowerEmail.Mailer,
    adapter: Swoosh.Adapters.Postmark,
    api_key: System.fetch_env!("POSTMARK_API_KEY")
end
