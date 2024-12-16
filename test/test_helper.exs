Mox.defmock(MeetupBot.Meetup.TestHost, for: MeetupBot.Meetup.Host)
Mox.defmock(MeetupBot.GDG.TestHost, for: MeetupBot.GDG.Host)

defmodule Helpers do
  def bypass_meetup do
    bypass = Bypass.open()
    url = "http://localhost:#{bypass.port}"
    Mox.expect(MeetupBot.Meetup.TestHost, :connect_url, fn -> url end)

    bypass
  end

  def bypass_gdg do
    bypass = Bypass.open()
    url = "http://localhost:#{bypass.port}"
    Mox.expect(MeetupBot.GDG.TestHost, :connect_url, fn -> url end)

    bypass
  end
end

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(MeetupBot.Repo, :manual)
