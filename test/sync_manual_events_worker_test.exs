defmodule MeetupBot.SyncManualEventsWorkerTest do
  use ExUnit.Case, async: false

  alias MeetupBot.MeetupCache
  alias MeetupBot.SyncManualEventsWorker
  alias MeetupBot.Repo
  alias MeetupBot.Event

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(MeetupBot.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)

    :ok
  end

  test "insert manual meetups", %{} do
    assert :ok = SyncManualEventsWorker.perform(%Oban.Job{})

    assert [meetup] = MeetupCache.all()

    assert meetup.source_id == "1"
    assert meetup.name == "OWU Code Pop"
  end

  test "delete manual meetups not present in the hardcoaded list", %{} do
    %Event{
      source: "manual",
      source_id: "-1",
      datetime: ~N[2024-03-30 19:00:00]
    }
    |> Repo.insert!()

    assert :ok = SyncManualEventsWorker.perform(%Oban.Job{})

    assert [meetup] = MeetupCache.all()

    assert meetup.source_id == "1"
    assert meetup.name == "OWU Code Pop"
  end
end
