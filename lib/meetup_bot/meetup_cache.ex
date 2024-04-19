defmodule MeetupBot.MeetupCache do
  use Agent

  def start_link(_) do
    Agent.start_link(fn -> [] end, name: __MODULE__)
  end

  def values do
    Agent.get(__MODULE__, & &1)
  end

  def update(meetups) do
    Agent.update(__MODULE__, fn _state -> meetups end)
  end
end
