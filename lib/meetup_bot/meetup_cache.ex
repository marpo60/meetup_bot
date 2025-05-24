defmodule MeetupBot.MeetupCache do
  alias MeetupBot.Event
  alias MeetupBot.Repo
  alias MeetupBot.Constants

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

  # Meant to be used for external sources (eg. GDG and meetup),
  # for which the event list we get is only the UPCOMING ones:
  def sync_upcoming_external_events(events, source) do
    update_or_create(events)
    delete_other_stored_events_from_source(events, source, only_upcoming: true)
  end

  # Meant to be used with manual events, for which we have the full list
  # of events (past and future) and we substitute the whole list every time:
  def sync_manual_events(events) do
    update_or_create(events)
    delete_other_stored_events_from_source(events, Constants.manual_source())
  end

  defp update_or_create(events) do
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

  defp delete_other_stored_events_from_source(events, source, opts \\ []) do
    # Deletes events stored on the DB from the provided source,
    # that are not included in the events lists
    # (because it means the event was canceled)
    source_ids = Enum.map(events, & &1.source_id)

    query = Event
    |> where([e], e.source == ^source)
    |> where([e], e.source_id not in ^source_ids)

    query = if opts[:only_upcoming] do
      now = DateTime.now!("America/Montevideo") |> DateTime.to_naive()
      where(query, [e], e.datetime > ^now)
    else
      query
    end

    Repo.delete_all(query)
  end
end
