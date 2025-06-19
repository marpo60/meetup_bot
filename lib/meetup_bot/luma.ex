defmodule MeetupBot.Luma do
  defmodule Host do
    @callback connect_url() :: String.t()
  end

  defmodule ProdHost do
    @behaviour Host

    def connect_url, do: "https://api.lu.ma"
  end

  @calendar_ids [
    # Cursor Community
    "cal-61Cv6COs4g9GKw7",
    # SwiftMate
    "cal-Je0mc758PtYqTba"
    # Add more calendar ids here, e.g. "cal-XXXXXXX" # Calendar Name
  ]

  def fetch_upcoming_meetups do
    @calendar_ids
    |> Enum.flat_map(&fetch_upcoming_events_from_calendar/1)
  end

  defp fetch_upcoming_events_from_calendar(calendar_id) do
    response =
      Req.new(base_url: host().connect_url())
      |> OpentelemetryReq.attach(span_name: "meetup_bot.req")
      |> Req.get!(
        url: "/calendar/get-items",
        params: [
          calendar_api_id: calendar_id,
          period: "future",
          pagination_limit: 20
        ]
      )

    response.body["entries"]
    |> Enum.filter(fn event ->
      get_in(event, ["event", "geo_address_info", "country"]) == "Uruguay"
    end)
    |> Enum.map(& &1["event"])
    |> Enum.map(&process_event/1)
  end

  defp process_event(event) do
    {:ok, start_dt, _} = DateTime.from_iso8601(event["start_at"])
    start_dt = DateTime.shift_zone!(start_dt, "America/Montevideo")
    {:ok, end_dt, _} = DateTime.from_iso8601(event["end_at"])
    end_dt = DateTime.shift_zone!(end_dt, "America/Montevideo")

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

  defp host, do: Keyword.fetch!(config(), :host)
  defp config, do: Application.fetch_env!(:meetup_bot, :luma)
end
