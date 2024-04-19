defmodule MeetupBot.Repo.Migrations.AddOban do
  use Ecto.Migration

  def change do
    Oban.Migrations.up()
  end
end
