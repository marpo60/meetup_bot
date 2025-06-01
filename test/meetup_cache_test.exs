defmodule MeetupBot.MeetupCacheTest do
  use ExUnit.Case, async: false

  alias MeetupBot.MeetupCache
  alias MeetupBot.Repo
  alias MeetupBot.Event

  import Helpers

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(MeetupBot.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)

    :ok
  end

  describe "update_or_create/1" do
    test "creates a new event with all given attributes when it didn't previously exist" do
      # Use all the available sources
      events =
        for source <- Event.sources() do
          %{
            source: source,
            source_id: "123",
            name: "Elixir Meetup",
            title: "Testing with ExUnit",
            event_url: "http://example.com",
            datetime: ~N[2024-03-30 19:00:00],
            end_datetime: ~N[2024-03-30 21:00:00]
          }
        end

      MeetupCache.update_or_create(events)

      [event, _gdg, _manual] = MeetupCache.all()

      assert event.source == "meetup"
      assert event.source_id == "123"
      assert event.name == "Elixir Meetup"
      assert event.title == "Testing with ExUnit"
      assert event.event_url == "http://example.com"
      assert event.datetime == ~N[2024-03-30 19:00:00]
      assert event.end_datetime == ~N[2024-03-30 21:00:00]
    end

    test "updates existing events with new information" do
      %Event{
        source: "meetup",
        source_id: "123",
        name: "Old Name",
        title: "Old Title",
        event_url: "http://old.com",
        datetime: ~N[2024-03-30 19:00:00],
        end_datetime: ~N[2024-03-30 21:00:00]
      }
      |> Repo.insert!()

      events = [
        %{
          source: "meetup",
          source_id: "123",
          name: "New Name",
          title: "New Title",
          event_url: "http://new.com",
          datetime: ~N[2024-03-31 19:00:00],
          end_datetime: ~N[2024-03-31 21:00:00]
        }
      ]

      MeetupCache.update_or_create(events)

      [event] = MeetupCache.all()

      assert event.source_id == "123"
      assert event.name == "New Name"
      assert event.title == "New Title"
      assert event.event_url == "http://new.com"
      assert event.datetime == ~N[2024-03-31 19:00:00]
      assert event.end_datetime == ~N[2024-03-31 21:00:00]
    end

    test "does not override events from other sources with the same ID" do
      # Existing GDG event with same id as meetup event:
      %Event{
        source: "GDG",
        source_id: "123",
        name: "GDG Event",
        title: "GDG Title",
        event_url: "http://gdg.com",
        datetime: ~N[2024-03-30 19:00:00],
        end_datetime: ~N[2024-03-30 21:00:00]
      }
      |> Repo.insert!()

      # An meetup event with the same id:
      events = [
        %{
          source: "meetup",
          source_id: "123",
          name: "Meetup Event",
          title: "Meetup Title",
          event_url: "http://meetup.com",
          datetime: ~N[2024-04-30 19:00:00],
          end_datetime: ~N[2024-04-30 21:00:00]
        }
      ]

      MeetupCache.update_or_create(events)

      [gdg_event, _meetup_event] = MeetupCache.all()

      assert gdg_event.source == "GDG"
      assert gdg_event.source_id == "123"
      assert gdg_event.title == "GDG Title"
      assert gdg_event.event_url == "http://gdg.com"
      assert gdg_event.datetime == ~N[2024-03-30 19:00:00]
      assert gdg_event.end_datetime == ~N[2024-03-30 21:00:00]
    end
  end

  describe "sync/2" do
    test "deletes upcoming events from same source that are no longer in the API response" do
      for source <- Event.sources() do
        # Previous Event
        %Event{
          source: source,
          source_id: "123",
          name: "Elixir Meetup in #{source}",
          title: "Testing with ExUnit",
          event_url: "http://example.com",
          datetime: ~N[2024-03-30 19:00:00],
          end_datetime: ~N[2024-03-30 21:00:00]
        }
        |> Repo.insert!()

        # Upcoming Event
        %Event{
          source: source,
          source_id: "456",
          name: "Elixir Meetup in #{source}",
          title: "Phoenix Liveview",
          event_url: "http://example.com",
          datetime: tomorrow(),
          end_datetime: tomorrow()
        }
        |> Repo.insert!()
      end

      # This event will continue to be part of the response of the API
      upcoming_meetup_event =
        %Event{
          source: "meetup",
          source_id: "789",
          name: "Elixir Meetup in meetup",
          title: "Phoenix Sync",
          event_url: "http://example.com",
          datetime: day_after_tomorrow(),
          end_datetime: day_after_tomorrow()
        }
        |> Repo.insert!()

      MeetupCache.sync("meetup", [Map.from_struct(upcoming_meetup_event)])

      [
        %{source_id: "123", source: "meetup"} = _previous_meetup,
        %{source_id: "123", source: "GDG"} = _previous_gdg,
        %{source_id: "123", source: "manual"} = _previous_manual,
        %{source_id: "456", source: "GDG"} = _upcoming_gdg,
        %{source_id: "456", source: "manual"} = _upcoming_manual,
        %{source_id: "789", source: "meetup"} = _upcoming_meetup
      ] = MeetupCache.all()

      MeetupCache.sync("GDG", [])

      [
        %{source_id: "123", source: "meetup"} = _previous_meetup,
        %{source_id: "123", source: "GDG"} = _previous_gdg,
        %{source_id: "123", source: "manual"} = _previous_manual,
        %{source_id: "456", source: "manual"} = _upcoming_manual,
        %{source_id: "789", source: "meetup"} = _upcoming_meetup
      ] = MeetupCache.all()

      # This will delete both because only external source take into
      # consideration upcoming
      MeetupCache.sync("manual", [])

      [
        %{source_id: "123", source: "meetup"} = _previous_meetup,
        %{source_id: "123", source: "GDG"} = _previous_gdg,
        %{source_id: "789", source: "meetup"} = _upcoming_meetup
      ] = MeetupCache.all()
    end
  end
end
