defmodule MeetupBot.Eventbrite do
  defmodule Host do
    @callback connect_url() :: String.t()
  end

  defmodule ProdHost do
    @behaviour Host

    def connect_url, do: "https://www.eventbriteapi.com"
  end

  alias MeetupBot.Event

  # The organizer id is the number at the end of the organizer page url
  # e.g. https://www.eventbrite.com/o/organizer-name-12345678901
  @organizer_ids [
    # OWU
    "109017238961"
    # Add more organizer ids here, e.g. "12345678901" # Organizer Name
  ]

  def fetch_upcoming_meetups(organizer_ids \\ @organizer_ids) do
    organizer_ids
    |> Enum.flat_map(&fetch_upcoming_events_from_organizer/1)
  end

  defp fetch_upcoming_events_from_organizer(organizer_id) do
    response =
      Req.new(base_url: host().connect_url(), auth: {:bearer, token()})
      |> OpentelemetryReq.attach(span_name: "meetup_bot.req")
      |> Req.get!(
        url: "/v3/organizers/#{organizer_id}/events/",
        params: [
          status: "live",
          order_by: "start_asc",
          expand: "venue,organizer"
        ]
      )

    response.body["events"]
    |> Enum.map(&process_event/1)
  end

  defp process_event(event) do
    {:ok, start_dt, _} = DateTime.from_iso8601(event["start"]["utc"])
    start_dt = DateTime.shift_zone!(start_dt, "America/Montevideo")
    {:ok, end_dt, _} = DateTime.from_iso8601(event["end"]["utc"])
    end_dt = DateTime.shift_zone!(end_dt, "America/Montevideo")

    title = event["name"]["text"]

    venue =
      if event["online_event"] do
        nil
      else
        get_in(event, ["venue", "name"])
      end

    %{
      source: Event.eventbrite_source(),
      source_id: event["id"],
      name: get_in(event, ["organizer", "name"]) || title,
      title: title,
      event_url: event["url"],
      datetime: DateTime.to_naive(start_dt),
      end_datetime: DateTime.to_naive(end_dt),
      venue: venue
    }
  end

  defp host, do: Keyword.fetch!(config(), :host)
  defp token, do: Keyword.get(config(), :token)
  defp config, do: Application.fetch_env!(:meetup_bot, :eventbrite)
end
