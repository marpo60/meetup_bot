defmodule MeetupBot.MeetupCache do
  alias MeetupBot.Event
  alias MeetupBot.Repo

  import Ecto.Query

  def values do
    now = DateTime.now!("America/Montevideo")
    next_month = DateTime.shift(now, month: 1)

    Event
    |> where([e], e.datetime > ^now)
    |> where([e], e.datetime < ^next_month)
    |> order_by([e], e.datetime)
    |> Repo.all()
  end

  def all do
    Event
    |> order_by([e], e.datetime)
    |> Repo.all()
  end

  def sync(source, events) do
    update_or_create(events)
    delete_events_not_present_in_source(source, events)
  end

  def update_or_create(events) do
    events
    |> Enum.each(fn e ->
      case Repo.get_by(Event, %{source: e.source, source_id: e.source_id}) do
        nil -> %Event{}
        event -> event
      end
      |> Event.changeset(e)
      |> Repo.insert_or_update()
    end)
  end

  # Deletes events stored on the DB from the provided source,
  # that are not included in the events lists
  # because it means the event was canceled
  #
  # When used with external source (eg. GDG and meetup),
  # the event list we get is only the upcoming ones
  #
  # When used with manual source the event list will be the full list
  defp delete_events_not_present_in_source(source, events) do
    source_ids = Enum.map(events, & &1.source_id)

    query = Event
            |> where([e], e.source == ^source)
            |> where([e], e.source_id not in ^source_ids)

    query = if source != Event.manual_source() do
      now = DateTime.now!("America/Montevideo")
      query = query |> where([e], e.datetime > ^now)
    else
      query
    end

    query |> Repo.delete_all()
  end
end
