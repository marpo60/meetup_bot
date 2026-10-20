defmodule MeetupBot.EventbriteTest do
  use ExUnit.Case, async: false

  alias MeetupBot.Eventbrite
  alias MeetupBot.MeetupCache
  alias MeetupBot.Event

  import Helpers

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(MeetupBot.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)

    :ok
  end

  test "fetch_upcoming_meetups/1 returns the organizer live events" do
    TestServer.add(test_server_eventbrite(), "/v3/organizers/123/events/",
      via: :get,
      to: fn conn ->
        assert ["Bearer test-token"] = Plug.Conn.get_req_header(conn, "authorization")
        assert %{"status" => "live"} = conn.query_params

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, """
        {
          "pagination": {"has_more_items": false},
          "events": [
            {
              "id": "evt-1",
              "name": {"text": "WTM Meetup"},
              "url": "https://www.eventbrite.com/e/wtm-meetup-1",
              "start": {"utc": "2024-03-30T22:00:00Z", "local": "2024-03-30T19:00:00"},
              "end": {"utc": "2024-03-31T01:00:00Z", "local": "2024-03-30T22:00:00"},
              "online_event": false,
              "venue": {"name": "Sinergia"},
              "organizer": {"name": "Women Techmakers Uruguay"}
            },
            {
              "id": "evt-2",
              "name": {"text": "WTM Online"},
              "url": "https://www.eventbrite.com/e/wtm-online-2",
              "start": {"utc": "2024-04-02T22:00:00Z", "local": "2024-04-02T19:00:00"},
              "end": {"utc": "2024-04-02T23:00:00Z", "local": "2024-04-02T20:00:00"},
              "online_event": true,
              "venue": null,
              "organizer": {"name": "Women Techmakers Uruguay"}
            }
          ]
        }
        """)
      end
    )

    events = Eventbrite.fetch_upcoming_meetups(["123"])
    MeetupCache.sync(Event.eventbrite_source(), events)

    assert [in_person, online] = MeetupCache.all()

    assert in_person.source == "eventbrite"
    assert in_person.source_id == "evt-1"
    assert in_person.name == "Women Techmakers Uruguay"
    assert in_person.title == "WTM Meetup"
    assert in_person.event_url == "https://www.eventbrite.com/e/wtm-meetup-1"
    assert in_person.datetime == ~N[2024-03-30 19:00:00]
    assert in_person.end_datetime == ~N[2024-03-30 22:00:00]
    assert in_person.venue == "Sinergia"

    assert online.source_id == "evt-2"
    assert online.venue == nil
  end
end
