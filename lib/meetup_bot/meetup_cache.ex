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

  def update(events) do
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

  def sync_manual(events) do
    update(events)

    ids = Enum.map(events, &(&1.source_id))

    Event
    |> where([e], e.source == "manual")
    |> where([e], e.source_id not in ^ids)
    |> Repo.delete_all
  end
end
