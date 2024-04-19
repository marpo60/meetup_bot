defmodule MeetupBot.Repo do
  use Ecto.Repo, otp_app: :meetup_bot, adapter: Ecto.Adapters.SQLite3
end
