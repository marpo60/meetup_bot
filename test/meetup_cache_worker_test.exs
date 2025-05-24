defmodule MeetupBot.MeetupCacheWorkerTest do
  use ExUnit.Case, async: false

  alias MeetupBot.MeetupCache
  alias MeetupBot.MeetupCacheWorker

  import TestDateHelpers
  import ApiStubHelpers

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(MeetupBot.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)

    :ok
  end

  test "perform/1 fetches and stores new meetup events" do
    stub_meetup_response([
      %{
        id: "123",
        title: "Testing with ExUnit",
        eventUrl: "http://example.com",
        dateTime: tomorrow(),
        endTime: day_after_tomorrow()
      }
    ])

    assert :ok = MeetupCacheWorker.perform(%Oban.Job{})

    events = MeetupCache.all()
    assert length(events) == 1

    event = hd(events)
    assert event.source == "meetup"
    assert event.source_id == "123"
  end
end
