defmodule MeetupBot.Event do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, only: [:id, :name, :title, :datetime, :end_datetime, :event_url]}

  schema "events" do
    field(:name, :string)
    field(:title, :string)
    field(:datetime, :naive_datetime)
    field(:end_datetime, :naive_datetime)
    field(:event_url, :string)

    field(:source, :string)
    field(:source_id, :string)
  end

  def changeset(event, params \\ %{}) do
    fields = [:name, :title, :datetime, :end_datetime, :source, :source_id, :event_url]

    event
    |> cast(params, fields)
    |> unique_constraint([:source, :source_id])
    |> validate_required(fields)
  end
end
