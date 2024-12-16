defmodule MeetupBot.RouterTest do
  use ExUnit.Case, async: true
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
    %Event{
      name: "Name",
      title: "Title",
      datetime: ~N[2024-01-01 19:00:00],
      end_datetime: ~N[2024-01-01 20:00:00],
      event_url: "https://example.com/event",
      source: "meetup",
      source_id: "123"
    }
    |> Repo.insert!()

    conn = conn(:get, "/json") |> Router.call([])

    response = Jason.decode!(conn.resp_body)
    assert %{"meetups" => [meetup]} = response

    assert meetup == %{
             "name" => "Name",
             "datetime" => "2024-01-01T19:00:00",
             "end_datetime" => "2024-01-01T20:00:00",
             "event_url" => "https://example.com/event",
             "title" => "Title"
           }
  end
end
