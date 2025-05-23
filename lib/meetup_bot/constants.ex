defmodule MeetupBot.Constants do
  @doc "Source identifier for GDG events"
  def gdg_source, do: "gdg"

  @doc "Source identifier for Meetup events"
  def meetup_source, do: "meetup"

  @doc "Source identifier for manual events"
  def manual_source, do: "manual"
end
