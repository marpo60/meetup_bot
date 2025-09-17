defmodule MeetupBot.SyncExternalEventsTest do
  use ExUnit.Case, async: false

  alias MeetupBot.MeetupCache
  alias MeetupBot.MeetupCacheWorker
  alias MeetupBot.GDGCacheWorker
  alias MeetupBot.LumaCacheWorker
  alias MeetupBot.Repo
  alias MeetupBot.Event

  import Helpers

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(MeetupBot.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)

    :ok
  end

  test "perform/1 stores new meetups", %{} do
    Bypass.expect(bypass_meetup(), "POST", "/gql-ext", fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, """
      {
        "data": {
          "g0": {
            "name": "Elixir Meetup",
            "events": {
              "edges": [
                {
                  "node": {
                    "id": "123",
                    "title": "Testing with ExUnit",
                    "eventUrl": "http://example.com",
                    "dateTime": "2024-03-28T22:00:00-03:00",
                    "endTime": "2024-03-28T23:00:00-03:00"
                  }
                }
              ]
            }
          }
        }
      }
      """)
    end)

    Bypass.expect(bypass_gdg(), "GET", "/api/event", fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, """
      {
        "results": [
          {
            "id": 456,
            "title": "Google Cloud Platform",
            "url": "http://gdg.example.com",
            "start_date": "2024-03-29T19:00:00",
            "end_date": "2024-03-29T21:00:00"
          }
        ]
      }
      """)
    end)

    Bypass.expect(bypass_luma(), "GET", "/calendar/get-items", fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, """
      {
        "entries": [
          {
            "event": {
              "api_id": "evt-789",
              "name": "Cursor Meetup Montevideo",
              "start_at": "2024-03-30T19:00:00.000Z",
              "end_at": "2024-03-30T23:00:00.000Z",
              "timezone": "America/Montevideo",
              "url": "cursor-test",
              "geo_address_info": {
                "country": "Uruguay"
              }
            }
          }
        ]
      }
      """)
    end)

    assert :ok = MeetupCacheWorker.perform(%Oban.Job{})
    assert :ok = GDGCacheWorker.perform(%Oban.Job{})
    assert :ok = LumaCacheWorker.perform(%Oban.Job{})

    assert [meetup, gdg, luma] = MeetupCache.all()

    assert meetup.source_id == "123"
    assert meetup.name == "Elixir Meetup"

    assert gdg.source_id == "456"
    assert gdg.name == "GDG"

    assert luma.source_id == "evt-789"
    assert luma.name == "Cursor Meetup Montevideo"
  end

  test "perform/1 update existings meetups", %{} do
    %Event{
      source: "meetup",
      source_id: "123",
      datetime: ~N[2024-03-28 19:00:00]
    }
    |> Repo.insert!()

    %Event{
      source: "GDG",
      source_id: "456",
      datetime: ~N[2024-03-30 19:00:00]
    }
    |> Repo.insert!()

    %Event{
      source: "luma",
      source_id: "evt-789",
      datetime: ~N[2024-03-30 19:00:00]
    }
    |> Repo.insert!()

    Bypass.expect(bypass_meetup(), "POST", "/gql-ext", fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, """
      {
        "data": {
          "g0": {
            "name": "Elixir Meetup",
            "events": {
              "edges": [
                {
                  "node": {
                    "id": "123",
                    "title": "Testing with ExUnit",
                    "eventUrl": "http://example.com",
                    "dateTime": "2024-03-29T19:00:00-03:00",
                    "endTime": "2024-03-29T23:00:00-03:00"
                  }
                }
              ]
            }
          }
        }
      }
      """)
    end)

    Bypass.expect(bypass_gdg(), "GET", "/api/event", fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, """
      {
        "results": [
          {
            "id": 456,
            "title": "Google Cloud Platform",
            "url": "http://gdg.example.com",
            "start_date": "2024-03-31T19:00:00",
            "end_date": "2024-03-31T23:00:00"
          }
        ]
      }
      """)
    end)

    Bypass.expect(bypass_luma(), "GET", "/calendar/get-items", fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, """
      {
        "entries": [
          {
            "event": {
              "api_id": "evt-789",
              "name": "Cursor Meetup Montevideo Updated",
              "start_at": "2024-04-01T19:00:00.000Z",
              "end_at": "2024-04-01T23:00:00.000Z",
              "timezone": "America/Montevideo",
              "url": "cursor-updated",
              "geo_address_info": {
                "country": "Uruguay"
              }
            }
          }
        ]
      }
      """)
    end)

    assert :ok = MeetupCacheWorker.perform(%Oban.Job{})
    assert :ok = GDGCacheWorker.perform(%Oban.Job{})
    assert :ok = LumaCacheWorker.perform(%Oban.Job{})

    [meetup, gdg, luma] = MeetupCache.all()
    assert meetup.datetime == ~N[2024-03-29 19:00:00]
    assert gdg.datetime == ~N[2024-03-31 19:00:00]
    assert luma.datetime == ~N[2024-04-01 16:00:00]
  end

  test "perform/1 delete meetups not longer present in source", %{} do
    %Event{
      source: "meetup",
      source_id: "123",
      datetime: ~N[2030-03-28 19:00:00]
    }
    |> Repo.insert!()

    %Event{
      source: "GDG",
      source_id: "456",
      datetime: ~N[2030-03-30 19:00:00]
    }
    |> Repo.insert!()

    %Event{
      source: "luma",
      source_id: "evt-789",
      datetime: ~N[2030-04-01 19:00:00]
    }
    |> Repo.insert!()

    Bypass.expect(bypass_meetup(), "POST", "/gql-ext", fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, """
      {
        "data": {
        }
      }
      """)
    end)

    Bypass.expect(bypass_gdg(), "GET", "/api/event", fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, """
      {
        "results": []
      }
      """)
    end)

    Bypass.expect(bypass_luma(), "GET", "/calendar/get-items", fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, """
      {
        "entries": []
      }
      """)
    end)

    assert :ok = MeetupCacheWorker.perform(%Oban.Job{})
    assert :ok = GDGCacheWorker.perform(%Oban.Job{})
    assert :ok = LumaCacheWorker.perform(%Oban.Job{})

    [] = MeetupCache.all()
  end
end
