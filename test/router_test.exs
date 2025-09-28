defmodule MeetupBot.RouterTest do
  use ExUnit.Case, async: false
  use Plug.Test

  alias MeetupBot.Router
  alias MeetupBot.Repo
  alias MeetupBot.Event

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(MeetupBot.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)

    :ok
  end

  test "GET /json returns meetups as JSON" do
    date = Date.utc_today() |> Date.add(2)
    datetime = NaiveDateTime.new!(date, ~T[19:00:00])
    end_datetime = NaiveDateTime.new!(date, ~T[20:00:00])

    e =
      %Event{
        name: "Name",
        title: "Title",
        datetime: datetime,
        end_datetime: end_datetime,
        event_url: "https://example.com/event",
        source: "meetup",
        source_id: "123"
      }
      |> Repo.insert!()

    conn = conn(:get, "/json") |> Router.call([])

    response = Jason.decode!(conn.resp_body)
    assert %{"meetups" => [meetup]} = response

    assert meetup == %{
             "id" => e.id,
             "name" => "Name",
             "datetime" => NaiveDateTime.to_iso8601(datetime),
             "end_datetime" => NaiveDateTime.to_iso8601(end_datetime),
             "event_url" => "https://example.com/event",
             "title" => "Title",
             "venue" => nil
           }
  end
end
