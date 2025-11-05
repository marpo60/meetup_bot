defmodule MeetupBot.Repo.Migrations.AddVenueToEvents do
  use Ecto.Migration

  def change do
    alter table(:events) do
      add :venue, :string
    end
  end
end
