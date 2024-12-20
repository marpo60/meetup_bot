defmodule MeetupBot.RouterTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias MeetupBot.Router
  alias MeetupBot.Repo
  alias MeetupBot.Event

  test "GET /json returns meetups as JSON" do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(MeetupBot.Repo)

    %Event{
      name: "Name",
      title: "Title",
      datetime: ~N[2024-01-01 19:00:00],
      end_datetime: ~N[2024-01-01 20:00:00],
      event_url: "https://example.com/event",
      source: "meetup",
      source_id: "123"
    } |> Repo.insert!()

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
