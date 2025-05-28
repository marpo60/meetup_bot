defmodule MeetupBot.Luma do
  @moduledoc """
  Fetches upcoming events from the Luma calendar API and filters for events in Uruguay.
  """

  @calendar_ids [
    "cal-61Cv6COs4g9GKw7" # Cursor Community
    # Add more calendar ids here, e.g. "cal-XXXXXXX" # Calendar Name
  ]

  def fetch_uruguay_events do
    @calendar_ids
    |> Enum.flat_map(&fetch_uruguay_events_from_calendar/1)
  end

  defp fetch_uruguay_events_from_calendar(calendar_id) do
    api_url = "https://api.lu.ma/calendar/get?api_id=" <> calendar_id

    response =
      Req.get!(api_url)
      |> Map.fetch!(:body)
      |> Jason.decode!()

    response["featured_items"]
    |> Enum.map(& &1["event"])
    |> Enum.filter(fn event ->
      get_in(event, ["geo_address_info", "country"]) == "Uruguay"
    end)
    |> Enum.map(&process_event/1)
  end

  defp process_event(event) do
    {:ok, start_dt, _} = DateTime.from_iso8601(event["start_at"])
    {:ok, end_dt, _} = DateTime.from_iso8601(event["end_at"])

    %{
      source: "luma",
      source_id: event["api_id"],
      name: event["name"],
      title: event["name"],
      event_url: "https://lu.ma/" <> event["url"],
      datetime: DateTime.to_naive(start_dt),
      end_datetime: DateTime.to_naive(end_dt)
    }
  end
end
