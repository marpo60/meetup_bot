defmodule MeetupBot.MeetupCalendar do
  def to_ics(meetups) do
    """
    BEGIN:VCALENDAR
    VERSION:2.0
    PRODID:MeetupBot
    BEGIN:VTIMEZONE
    TZID:America/Montevideo
    X-LIC-LOCATION:America/Montevideo
    BEGIN:STANDARD
    TZOFFSETFROM:-0300
    TZOFFSETTO:-0300
    TZNAME:-03
    DTSTART:19700101T000000
    END:STANDARD
    END:VTIMEZONE
    #{for meetup <- meetups, do: build_event(meetup)}
    END:VCALENDAR
    """
  end

  defp build_event(meetup) do
    """
    BEGIN:VEVENT
    DTSTART;TZID=America/Montevideo:#{format_datetime(meetup.datetime)}
    DTEND;TZID=America/Montevideo:#{format_datetime(meetup.end_datetime)}
    SUMMARY:#{meetup.title}
    DESCRIPTION:#{meetup.event_url}
    UID:#{meetup.source_id}@meetup_bot.local
    END:VEVENT
    """
  end

  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%Y%m%dT%H%M%S")
  end
end
