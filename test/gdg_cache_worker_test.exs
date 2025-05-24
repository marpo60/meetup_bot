defmodule MeetupBot.GDGCacheWorkerTest do
  use ExUnit.Case, async: false

  alias MeetupBot.MeetupCache
  alias MeetupBot.GDGCacheWorker

  import TestDateHelpers
  import ApiStubHelpers

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(MeetupBot.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)

    :ok
  end

  test "perform/1 fetches and stores new gdg events" do
    stub_gdg_response([
      %{
        id: 456,
        title: "Google Cloud Platform",
        url: "http://gdg.example.com",
        start_date: tomorrow(),
        end_date: day_after_tomorrow()
      }
    ])

    assert :ok = GDGCacheWorker.perform(%Oban.Job{})

    events = MeetupCache.all()
    assert length(events) == 1

    event = hd(events)
    assert event.source == "GDG"
    assert event.source_id == "456"
    assert event.title == "Google Cloud Platform"
    assert event.event_url == "http://gdg.example.com"
  end
end
