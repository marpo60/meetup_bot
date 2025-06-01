defmodule MeetupBot.GDG do
  defmodule Host do
    @callback connect_url() :: String.t()
  end

  defmodule ProdHost do
    @behaviour Host

    def connect_url, do: "https://gdg.community.dev"
  end

  alias MeetupBot.Event


  def fetch_live_events() do
    response =
      Req.new(base_url: host().connect_url())
      |> OpentelemetryReq.attach(span_name: "meetup_bot.req")
      |> Req.get!(url: "/api/event", params: [chapter: 902, status: "Live"])

    response.body["results"]
    |> Enum.map(&process_response/1)
    |> Enum.filter(& &1)
  end

  defp process_response(meetup) do
    %{
      "id" => id,
      "title" => title,
      "url" => event_url,
      "start_date" => dt,
      "end_date" => edt
    } = meetup

    {:ok, dt} = dt |> NaiveDateTime.from_iso8601()
    {:ok, edt} = edt |> NaiveDateTime.from_iso8601()

    %{
      source: Event.gdg_source(),
      source_id: id |> to_string,
      name: "GDG",
      title: title,
      event_url: event_url,
      datetime: dt,
      end_datetime: edt
    }
  end

  defp host, do: Keyword.fetch!(config(), :host)
  defp config, do: Application.fetch_env!(:meetup_bot, :gdg)
end
