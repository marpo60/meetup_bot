import Config

config :tower_email,
  environment: System.get_env("TARGET", to_string(config_env()))

if config_env() == :prod do
  config :tower_email, TowerEmail.Mailer,
    adapter: Swoosh.Adapters.Postmark,
    api_key: System.fetch_env!("POSTMARK_API_KEY")

  database_path =
    System.get_env("DATABASE_PATH") ||
      raise """
      environment variable DATABASE_PATH is missing.
      For example: /data/name/name.db
      """

  config :meetup_bot, MeetupBot.Repo, database: database_path
end
