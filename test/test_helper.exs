Mox.defmock(MeetupBot.Meetup.TestHost, for: MeetupBot.Meetup.Host)
Mox.defmock(MeetupBot.GDG.TestHost, for: MeetupBot.GDG.Host)
Mox.defmock(MeetupBot.Luma.TestHost, for: MeetupBot.Luma.Host)

defmodule Helpers do
  def bypass_meetup do
    bypass = Bypass.open()
    url = "http://localhost:#{bypass.port}"
    Mox.stub(MeetupBot.Meetup.TestHost, :connect_url, fn -> url end)

    bypass
  end

  def bypass_gdg do
    bypass = Bypass.open()
    url = "http://localhost:#{bypass.port}"
    Mox.stub(MeetupBot.GDG.TestHost, :connect_url, fn -> url end)

    bypass
  end

  def bypass_luma do
    bypass = Bypass.open()
    url = "http://localhost:#{bypass.port}"
    Mox.stub(MeetupBot.Luma.TestHost, :connect_url, fn -> url end)

    bypass
  end

  def tomorrow do
    DateTime.utc_now()
    |> DateTime.add(1, :day)
    |> DateTime.truncate(:second)
    |> DateTime.to_naive()
  end

  def day_after_tomorrow do
    DateTime.utc_now()
    |> DateTime.add(2, :day)
    |> DateTime.truncate(:second)
    |> DateTime.to_naive()
  end
end

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(MeetupBot.Repo, :manual)
