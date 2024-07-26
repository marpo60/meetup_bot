defmodule MeetupBot.GDG do
  def fetch_live_events() do
    response = Req.get!("https://gdg.community.dev/api/event", params: [chapter: 902, status: "Live"])

    response.body["results"]
    |> Enum.map(&process_response/1)
    |> Enum.filter(& &1)
    |> Enum.sort_by(& &1.datetime, NaiveDateTime)
  end

  defp process_response(meetup) do
    %{
      "id" => id,
      "title" => title,
      "url" => event_url,
      "start_date" => dt,
      "end_date" => edt
    } = meetup

    %{
      id: id,
      name: "GDG",
      title: title,
      event_url: event_url,
      datetime: dt,
      end_datetime: edt
    }
  end
end
