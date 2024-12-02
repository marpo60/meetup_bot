defmodule MeetupBot.Repo.Migrations.CreateEvents do
  use Ecto.Migration

  def change do
    create table(:events) do
      add :name, :string
      add :title, :string
      add :datetime, :naive_datetime
      add :end_datetime, :naive_datetime
      add :event_url, :string
      add :source, :string
      add :source_id, :string
    end

    create index("events", [:source, :source_id], unique: true)
  end
end
