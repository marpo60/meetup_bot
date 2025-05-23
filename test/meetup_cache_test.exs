defmodule MeetupBot.MeetupCacheTest do
  use ExUnit.Case, async: false

  alias MeetupBot.MeetupCache
  alias MeetupBot.Repo
  alias MeetupBot.Event

  import TestDateHelpers

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(MeetupBot.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)

    :ok
  end

  describe "sync_upcoming_external_events/2" do
    test "creates a new event with all given attributes when it didn't previously exist" do
      tomorrow_date = tomorrow() # defining as var to prevent flakeyness
      day_after_tomorrow_date = day_after_tomorrow()

      events = [
        %{
          source: "meetup",
          source_id: "123",
          name: "Elixir Meetup",
          title: "Testing with ExUnit",
          event_url: "http://example.com",
          datetime: tomorrow_date,
          end_datetime: day_after_tomorrow_date
        }
      ]

      MeetupCache.sync_upcoming_external_events(events, "meetup")

      stored_events = MeetupCache.all()
      assert length(stored_events) == 1

      event = hd(stored_events)
      assert event.source == "meetup"
      assert event.source_id == "123"
      assert event.name == "Elixir Meetup"
      assert event.title == "Testing with ExUnit"
      assert event.event_url == "http://example.com"
      assert event.datetime == tomorrow_date
      assert event.end_datetime == day_after_tomorrow_date
    end

    test "creates new events when new multiple events are given" do
      tomorrow_date = tomorrow()
      day_after_tomorrow_date = day_after_tomorrow()
      next_week_date = next_week()

      events = [
        %{
          source: "meetup",
          source_id: "123",
          name: "Elixir Meetup",
          title: "First Event",
          event_url: "http://example.com/1",
          datetime: tomorrow_date,
          end_datetime: day_after_tomorrow_date
        },
        %{
          source: "meetup",
          source_id: "456",
          name: "Elixir Meetup",
          title: "Second Event",
          event_url: "http://example.com/2",
          datetime: next_week_date,
          end_datetime: next_week_date
        }
      ]

      MeetupCache.sync_upcoming_external_events(events, "meetup")

      stored_events = MeetupCache.all()
      assert length(stored_events) == 2

      event_ids = Enum.map(stored_events, & &1.source_id)
      assert "123" in event_ids
      assert "456" in event_ids
    end

    test "updates existing events with new information" do
      yesterday_date = yesterday()
      tomorrow_date = tomorrow()
      day_after_tomorrow_date = day_after_tomorrow()

      %Event{
        source: "meetup",
        source_id: "123",
        name: "Old Name",
        title: "Old Title",
        event_url: "http://old.com",
        datetime: yesterday_date,
        end_datetime: yesterday_date
      }
      |> Repo.insert!()

      events = [
        %{
          source: "meetup",
          source_id: "123",
          name: "New Name",
          title: "New Title",
          event_url: "http://new.com",
          datetime: tomorrow_date,
          end_datetime: day_after_tomorrow_date
        }
      ]

      MeetupCache.sync_upcoming_external_events(events, "meetup")

      stored_events = MeetupCache.all()
      assert length(stored_events) == 1

      event = hd(stored_events)
      assert event.source_id == "123"
      assert event.name == "New Name"
      assert event.title == "New Title"
      assert event.event_url == "http://new.com"
      assert event.datetime == tomorrow_date
      assert event.end_datetime == day_after_tomorrow_date
    end

    test "does not override events from other sources with the same ID" do
      tomorrow_date = tomorrow()
      day_after_tomorrow_date = day_after_tomorrow()
      next_week_date = next_week()

      # Existing GDG event with same id as meetup event:
      %Event{
        source: "GDG",
        source_id: "123",
        name: "GDG Event",
        title: "GDG Title",
        event_url: "http://gdg.com",
        datetime: tomorrow_date,
        end_datetime: day_after_tomorrow_date
      }
      |> Repo.insert!()

      # Sync a meetup event with the same id:
      events = [
        %{
          source: "meetup",
          source_id: "123",
          name: "Meetup Event",
          title: "Meetup Title",
          event_url: "http://meetup.com",
          datetime: next_week_date,
          end_datetime: next_week_date
        }
      ]

      MeetupCache.sync_upcoming_external_events(events, "meetup")

      stored_events = MeetupCache.all()
      assert length(stored_events) == 2

      gdg_event = Enum.find(stored_events, &(&1.source == "GDG"))
      assert gdg_event != nil
      assert gdg_event.source_id == "123"
      assert gdg_event.title == "GDG Title"
      assert gdg_event.event_url == "http://gdg.com"
      assert gdg_event.datetime == tomorrow_date

      meetup_event = Enum.find(stored_events, &(&1.source == "meetup"))
      assert meetup_event != nil
      assert meetup_event.source_id == "123"
      assert meetup_event.title == "Meetup Title"
      assert meetup_event.event_url == "http://meetup.com"
      assert meetup_event.datetime == next_week_date
    end

    test "deletes upcoming events from same source that are no longer in the API response" do
      next_week_date = next_week()
      future_date = in_future_days(5)

      # Existing upcoming event that will be "cancelled" (not in new API response):
      %Event{
        source: "meetup",
        source_id: "cancelled-123",
        name: "Cancelled Event",
        title: "This will be cancelled",
        event_url: "http://cancelled.com",
        datetime: future_date,
        end_datetime: future_date
      }
      |> Repo.insert!()

      # API returns a new different event:
      events = [
        %{
          source: "meetup",
          source_id: "new-456",
          name: "New Event",
          title: "This is new",
          event_url: "http://new.com",
          datetime: next_week_date,
          end_datetime: next_week_date
        }
      ]

      MeetupCache.sync_upcoming_external_events(events, "meetup")

      stored_events = MeetupCache.all()
      assert length(stored_events) == 1

      event = hd(stored_events)
      assert event.source_id == "new-456"
      assert event.title == "This is new"
    end

    test "preserves past events from same source even if not in API response" do
      yesterday_date = yesterday()
      future_date = in_future_days(5)
      next_week_date = next_week()

      # Existing past event (should not be deleted):
      %Event{
        source: "meetup",
        source_id: "past-123",
        name: "Past Event",
        title: "This happened yesterday",
        event_url: "http://past.com",
        datetime: yesterday_date,
        end_datetime: yesterday_date
      }
      |> Repo.insert!()

      # Existing upcoming event that will be cancelled:
      %Event{
        source: "meetup",
        source_id: "cancelled-456",
        name: "Cancelled Event",
        title: "This will be cancelled",
        event_url: "http://cancelled.com",
        datetime: future_date,
        end_datetime: future_date
      }
      |> Repo.insert!()

      # API returns a new different event:
      events = [
        %{
          source: "meetup",
          source_id: "new-789",
          name: "New Event",
          title: "This is new",
          event_url: "http://new.com",
          datetime: next_week_date,
          end_datetime: next_week_date
        }
      ]

      MeetupCache.sync_upcoming_external_events(events, "meetup")

      stored_events = MeetupCache.all()
      assert length(stored_events) == 2

      source_ids = Enum.map(stored_events, & &1.source_id)
      assert "past-123" in source_ids      # Past event preserved
      assert "new-789" in source_ids       # New event added
      refute "cancelled-456" in source_ids # Upcoming event deleted
    end

    test "handles empty API response by deleting all upcoming events from that source" do
      yesterday_date = yesterday()
      future_date = in_future_days(5)

      # Existing past event (should be preserved)
      %Event{
        source: "meetup",
        source_id: "past-123",
        name: "Past Event",
        title: "This happened yesterday",
        event_url: "http://past.com",
        datetime: yesterday_date,
        end_datetime: yesterday_date
      }
      |> Repo.insert!()

      # Existing upcoming event (should be deleted)
      %Event{
        source: "meetup",
        source_id: "upcoming-456",
        name: "Upcoming Event",
        title: "This will be deleted",
        event_url: "http://upcoming.com",
        datetime: future_date,
        end_datetime: future_date
      }
      |> Repo.insert!()

      # Empty API response
      events = []

      MeetupCache.sync_upcoming_external_events(events, "meetup")

      stored_events = MeetupCache.all()
      assert length(stored_events) == 1

      event = hd(stored_events)
      assert event.source_id == "past-123"
    end

    test "works with different source types (gdg)" do
      tomorrow_date = tomorrow()
      day_after_tomorrow_date = day_after_tomorrow()

      events = [
        %{
          source: "GDG",
          source_id: "789",
          name: "GDG Event",
          title: "Google Cloud Platform",
          event_url: "http://gdg.example.com",
          datetime: tomorrow_date,
          end_datetime: day_after_tomorrow_date
        }
      ]

      MeetupCache.sync_upcoming_external_events(events, "GDG")

      stored_events = MeetupCache.all()
      assert length(stored_events) == 1

      event = hd(stored_events)
      assert event.source == "GDG"
      assert event.source_id == "789"
      assert event.name == "GDG Event"
    end

    test "only deletes upcoming events from specified source, not from other sources" do
      future_date_5 = in_future_days(5)
      future_date_6 = in_future_days(6)

      # Existing upcoming events from different sources
      %Event{
        source: "meetup",
        source_id: "meetup-123",
        name: "Meetup Event",
        title: "Meetup Title",
        event_url: "http://meetup.com",
        datetime: future_date_5,
        end_datetime: future_date_5
      }
      |> Repo.insert!()

      %Event{
        source: "GDG",
        source_id: "gdg-456",
        name: "GDG Event",
        title: "GDG Title",
        event_url: "http://gdg.com",
        datetime: future_date_6,
        end_datetime: future_date_6
      }
      |> Repo.insert!()

      # Syncs empty meetup events (should only delete meetup events)
      MeetupCache.sync_upcoming_external_events([], "meetup")

      stored_events = MeetupCache.all()
      assert length(stored_events) == 1

      event = hd(stored_events)
      assert event.source == "GDG"
      assert event.source_id == "gdg-456"
    end

    test "handles mix of new, updated, and deleted events in single operation" do
      yesterday_date = yesterday()
      tomorrow_date = tomorrow()
      day_after_tomorrow_date = day_after_tomorrow()
      next_week_date = next_week()
      future_date_10 = in_future_days(10)

      # Existing event that will be updated
      %Event{
        source: "meetup",
        source_id: "update-me",
        name: "Old Name",
        title: "Old Title",
        event_url: "http://old.com",
        datetime: yesterday_date,
        end_datetime: yesterday_date
      }
      |> Repo.insert!()

      # Existing event that will be deleted
      %Event{
        source: "meetup",
        source_id: "delete-me",
        name: "To Be Deleted",
        title: "Delete This",
        event_url: "http://delete.com",
        datetime: future_date_10,
        end_datetime: future_date_10
      }
      |> Repo.insert!()

      events = [
        %{
          source: "meetup",
          source_id: "update-me",
          name: "Updated Name",
          title: "Updated Title",
          event_url: "http://updated.com",
          datetime: tomorrow_date,
          end_datetime: day_after_tomorrow_date
        },
        %{
          source: "meetup",
          source_id: "brand-new",
          name: "New Event",
          title: "Brand New",
          event_url: "http://new.com",
          datetime: next_week_date,
          end_datetime: next_week_date
        }
      ]

      MeetupCache.sync_upcoming_external_events(events, "meetup")

      stored_events = MeetupCache.all()
      assert length(stored_events) == 2

      source_ids = Enum.map(stored_events, & &1.source_id)
      assert "update-me" in source_ids
      assert "brand-new" in source_ids
      refute "delete-me" in source_ids

      # Verifies the updated event has new values
      updated_event = Enum.find(stored_events, &(&1.source_id == "update-me"))
      assert updated_event.name == "Updated Name"
      assert updated_event.title == "Updated Title"
    end
  end

  describe "sync_manual_events/1" do
    test "creates new manual events when none exist" do
      tomorrow_date = tomorrow()
      day_after_tomorrow_date = day_after_tomorrow()
      yesterday_date = yesterday()

      events = [
        %{
          source: "manual",
          source_id: "manual-123",
          name: "Manual Event",
          title: "Hand-crafted Event",
          event_url: "http://manual.com",
          datetime: tomorrow_date,
          end_datetime: day_after_tomorrow_date
        },
        %{
          source: "manual",
          source_id: "manual-456",
          name: "Past Manual Event",
          title: "Already Happened",
          event_url: "http://past-manual.com",
          datetime: yesterday_date,
          end_datetime: yesterday_date
        }
      ]

      MeetupCache.sync_manual_events(events)

      stored_events = MeetupCache.all()
      assert length(stored_events) == 2

      event_ids = Enum.map(stored_events, & &1.source_id)
      assert "manual-123" in event_ids
      assert "manual-456" in event_ids

      future_event = Enum.find(stored_events, &(&1.source_id == "manual-123"))
      assert future_event.source == "manual"
      assert future_event.name == "Manual Event"
      assert future_event.title == "Hand-crafted Event"
      assert future_event.datetime == tomorrow_date

      past_event = Enum.find(stored_events, &(&1.source_id == "manual-456"))
      assert past_event.source == "manual"
      assert past_event.name == "Past Manual Event"
      assert past_event.datetime == yesterday_date
    end

    test "updates existing manual events with new information" do
      yesterday_date = yesterday()
      tomorrow_date = tomorrow()
      next_week_date = next_week()

      # Existing manual event
      %Event{
        source: "manual",
        source_id: "manual-update",
        name: "Old Manual Name",
        title: "Old Manual Title",
        event_url: "http://old-manual.com",
        datetime: yesterday_date,
        end_datetime: yesterday_date
      }
      |> Repo.insert!()

      # Updates with new information
      events = [
        %{
          source: "manual",
          source_id: "manual-update",
          name: "New Manual Name",
          title: "New Manual Title",
          event_url: "http://new-manual.com",
          datetime: tomorrow_date,
          end_datetime: next_week_date
        }
      ]

      MeetupCache.sync_manual_events(events)

      stored_events = MeetupCache.all()
      assert length(stored_events) == 1

      event = hd(stored_events)
      assert event.source_id == "manual-update"
      assert event.name == "New Manual Name"
      assert event.title == "New Manual Title"
      assert event.event_url == "http://new-manual.com"
      assert event.datetime == tomorrow_date
      assert event.end_datetime == next_week_date
    end

    test "preserves events from other sources when syncing manual events" do
      tomorrow_date = tomorrow()
      day_after_tomorrow_date = day_after_tomorrow()
      next_week_date = next_week()

      # Existing events from different sources
      %Event{
        source: "meetup",
        source_id: "meetup-preserve",
        name: "Meetup Event",
        title: "Should be preserved",
        event_url: "http://meetup-preserve.com",
        datetime: tomorrow_date,
        end_datetime: day_after_tomorrow_date
      }
      |> Repo.insert!()

      %Event{
        source: "GDG",
        source_id: "gdg-preserve",
        name: "GDG Event",
        title: "Should also be preserved",
        event_url: "http://gdg-preserve.com",
        datetime: next_week_date,
        end_datetime: next_week_date
      }
      |> Repo.insert!()

      events = [
        %{
          source: "manual",
          source_id: "manual-new",
          name: "New Manual Event",
          title: "Manual Title",
          event_url: "http://manual-new.com",
          datetime: tomorrow_date,
          end_datetime: tomorrow_date
        }
      ]

      MeetupCache.sync_manual_events(events)

      stored_events = MeetupCache.all()
      assert length(stored_events) == 3

      source_ids = Enum.map(stored_events, & &1.source_id)
      assert "meetup-preserve" in source_ids
      assert "gdg-preserve" in source_ids
      assert "manual-new" in source_ids
    end

    test "deletes all manual events not in the new list (both past and upcoming)" do
      yesterday_date = yesterday()
      tomorrow_date = tomorrow()
      next_week_date = next_week()

      # Existing manual events that will be deleted
      %Event{
        source: "manual",
        source_id: "manual-past-delete",
        name: "Past Manual to Delete",
        title: "This past event will be deleted",
        event_url: "http://past-delete.com",
        datetime: yesterday_date,
        end_datetime: yesterday_date
      }
      |> Repo.insert!()

      %Event{
        source: "manual",
        source_id: "manual-future-delete",
        name: "Future Manual to Delete",
        title: "This future event will be deleted",
        event_url: "http://future-delete.com",
        datetime: next_week_date,
        end_datetime: next_week_date
      }
      |> Repo.insert!()

      events = [
        %{
          source: "manual",
          source_id: "manual-new-replace",
          name: "Replacement Event",
          title: "This replaces all others",
          event_url: "http://replacement.com",
          datetime: tomorrow_date,
          end_datetime: tomorrow_date
        }
      ]

      MeetupCache.sync_manual_events(events)

      stored_events = MeetupCache.all()
      assert length(stored_events) == 1

      event = hd(stored_events)
      assert event.source_id == "manual-new-replace"
      assert event.title == "This replaces all others"
    end

    test "handles empty manual events list by deleting all manual events" do
      yesterday_date = yesterday()
      future_date = in_future_days(5)

      # Existing manual events that should be deleted
      %Event{
        source: "manual",
        source_id: "manual-past",
        name: "Past Manual",
        title: "Will be deleted",
        event_url: "http://past-manual.com",
        datetime: yesterday_date,
        end_datetime: yesterday_date
      }
      |> Repo.insert!()

      %Event{
        source: "manual",
        source_id: "manual-future",
        name: "Future Manual",
        title: "Will also be deleted",
        event_url: "http://future-manual.com",
        datetime: future_date,
        end_datetime: future_date
      }
      |> Repo.insert!()

      # Existing event from different source (should be preserved)
      %Event{
        source: "meetup",
        source_id: "meetup-keep",
        name: "Meetup Event",
        title: "Should be kept",
        event_url: "http://meetup-keep.com",
        datetime: future_date,
        end_datetime: future_date
      }
      |> Repo.insert!()

      # Empty manual events list
      MeetupCache.sync_manual_events([])

      stored_events = MeetupCache.all()
      assert length(stored_events) == 1

      event = hd(stored_events)
      assert event.source == "meetup"
      assert event.source_id == "meetup-keep"
    end

    test "replaces entire manual event collection in single operation" do
      yesterday_date = yesterday()
      tomorrow_date = tomorrow()
      day_after_tomorrow_date = day_after_tomorrow()
      next_week_date = next_week()

      # Existing manual events
      %Event{
        source: "manual",
        source_id: "manual-old-1",
        name: "Old Manual 1",
        title: "Will be replaced",
        event_url: "http://old1.com",
        datetime: yesterday_date,
        end_datetime: yesterday_date
      }
      |> Repo.insert!()

      %Event{
        source: "manual",
        source_id: "manual-old-2",
        name: "Old Manual 2",
        title: "Will also be replaced",
        event_url: "http://old2.com",
        datetime: tomorrow_date,
        end_datetime: tomorrow_date
      }
      |> Repo.insert!()

      # Replaces with completely new set
      events = [
        %{
          source: "manual",
          source_id: "manual-new-1",
          name: "New Manual 1",
          title: "Brand new event",
          event_url: "http://new1.com",
          datetime: day_after_tomorrow_date,
          end_datetime: day_after_tomorrow_date
        },
        %{
          source: "manual",
          source_id: "manual-new-2",
          name: "New Manual 2",
          title: "Another new event",
          event_url: "http://new2.com",
          datetime: next_week_date,
          end_datetime: next_week_date
        }
      ]

      MeetupCache.sync_manual_events(events)

      stored_events = MeetupCache.all()
      assert length(stored_events) == 2

      source_ids = Enum.map(stored_events, & &1.source_id)
      assert "manual-new-1" in source_ids
      assert "manual-new-2" in source_ids
      refute "manual-old-1" in source_ids
      refute "manual-old-2" in source_ids
    end

    test "handles mix of creating new and updating existing manual events" do
      yesterday_date = yesterday()
      tomorrow_date = tomorrow()
      next_week_date = next_week()

      # Existing manual event that will be updated
      %Event{
        source: "manual",
        source_id: "manual-update",
        name: "Old Manual Name",
        title: "Will be updated",
        event_url: "http://old-manual.com",
        datetime: yesterday_date,
        end_datetime: yesterday_date
      }
      |> Repo.insert!()

      # Mix of update and new events
      events = [
        %{
          source: "manual",
          source_id: "manual-update",
          name: "Updated Manual Name",
          title: "Was updated",
          event_url: "http://updated-manual.com",
          datetime: tomorrow_date,
          end_datetime: tomorrow_date
        },
        %{
          source: "manual",
          source_id: "manual-brand-new",
          name: "Brand New Manual",
          title: "Completely new",
          event_url: "http://brand-new.com",
          datetime: next_week_date,
          end_datetime: next_week_date
        }
      ]

      MeetupCache.sync_manual_events(events)

      stored_events = MeetupCache.all()
      assert length(stored_events) == 2

      updated_event = Enum.find(stored_events, &(&1.source_id == "manual-update"))
      assert updated_event.name == "Updated Manual Name"
      assert updated_event.title == "Was updated"
      assert updated_event.datetime == tomorrow_date

      new_event = Enum.find(stored_events, &(&1.source_id == "manual-brand-new"))
      assert new_event.name == "Brand New Manual"
      assert new_event.title == "Completely new"
      assert new_event.datetime == next_week_date
    end
  end
end
