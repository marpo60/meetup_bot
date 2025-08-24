Mox.defmock(MeetupBot.Meetup.TestHost, for: MeetupBot.Meetup.Host)
Mox.defmock(MeetupBot.GDG.TestHost, for: MeetupBot.GDG.Host)
Mox.defmock(MeetupBot.Luma.TestHost, for: MeetupBot.Luma.Host)

defmodule Helpers do
  def test_server_meetup do
    {:ok, test_server} = TestServer.start()
    Mox.stub(MeetupBot.Meetup.TestHost, :connect_url, fn -> TestServer.url(test_server) end)

    test_server
  end

  def test_server_gdg do
    {:ok, test_server} = TestServer.start()
    Mox.stub(MeetupBot.GDG.TestHost, :connect_url, fn -> TestServer.url(test_server) end)

    test_server
  end

  def test_server_luma do
    {:ok, test_server} = TestServer.start()
    Mox.stub(MeetupBot.Luma.TestHost, :connect_url, fn -> TestServer.url(test_server) end)

    test_server
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
