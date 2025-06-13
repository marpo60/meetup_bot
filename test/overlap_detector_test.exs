defmodule MeetupBot.OverlapDetectorTest do
  use ExUnit.Case, async: false

  alias MeetupBot.OverlapDetector
  alias MeetupBot.Event
  alias MeetupBot.Repo

  import ExUnit.CaptureLog

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(MeetupBot.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)

    :ok
  end

  describe "check/0" do
    test "works" do
      %Event{
        source: "meetup",
        source_id: "1",
        name: "Elixir Meetup",
        title: "Phoenix Sync",
        event_url: "http://example.com",
        datetime: ~N[2026-03-31 19:00:00],
        end_datetime: ~N[2026-03-31 21:00:00]
      }
      |> Repo.insert!()

      {:ok, pid} = OverlapDetector.start_link()

      %Event{
        source: "meetup",
        source_id: "2",
        name: "Ruby Meetup",
        title: "Rails Sync",
        event_url: "http://example.com",
        datetime: ~N[2026-03-31 19:00:00],
        end_datetime: ~N[2026-03-31 21:00:00]
      }
      |> Repo.insert!()

      output =
        capture_log(fn ->
          OverlapDetector.check(pid)
          :sys.get_state(pid)
        end)

      assert output =~
               """
               [critical]   New Overlap
                 1 - Elixir Meetup - 2026-03-31 19:00:00
                 2 - Ruby Meetup - 2026-03-31 19:00:00
               """
               |> String.trim()

      output =
        capture_log(fn ->
          OverlapDetector.check(pid)
          :sys.get_state(pid)
        end)

      refute output == "[critical]"
    end
  end
end
