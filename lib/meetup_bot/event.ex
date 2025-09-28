defmodule MeetupBot.Event do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder,
           only: [:id, :name, :title, :datetime, :end_datetime, :event_url, :venue]}

  schema "events" do
    field(:name, :string)
    field(:title, :string)
    field(:datetime, :naive_datetime)
    field(:end_datetime, :naive_datetime)
    field(:event_url, :string)
    field(:venue, :string)

    field(:source, :string)
    field(:source_id, :string)
  end

  def changeset(event, params \\ %{}) do
    required_fields = [:name, :title, :datetime, :end_datetime, :source, :source_id, :event_url]
    fields = required_fields ++ [:venue]

    event
    |> cast(params, fields)
    |> unique_constraint([:source, :source_id])
    |> validate_required(required_fields)
  end

  @doc "Source identifier for GDG events"
  def gdg_source, do: "GDG"

  @doc "Source identifier for Meetup events"
  def meetup_source, do: "meetup"

  @doc "Source identifier for manual events"
  def manual_source, do: "manual"

  @doc "Source identifier for Luma events"
  def luma_source, do: "luma"

  def sources do
    [
      meetup_source(),
      gdg_source(),
      manual_source(),
      luma_source()
    ]
  end
end
