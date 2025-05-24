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

defmodule ApiStubHelpers do
  @doc """
  Stubs the Meetup API response with the given events
  """
  def stub_meetup_response(events) when is_list(events) do

    edges = Enum.map(events, fn event ->
      %{
        "node" => %{
          "id" => event.id,
          "title" => event.title,
          "eventUrl" => event.eventUrl,
          "dateTime" => event.dateTime,
          "endTime" => event.endTime
        }
      }
    end)

    Bypass.expect(Helpers.bypass_meetup(), "POST", "/gql", fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, Jason.encode!(%{
        "data" => %{
          "g0" => %{
            "name" => "Elixir Meetup",
            "upcomingEvents" => %{
              "edges" => edges
            }
          }
        }
      }))
    end)
  end

  @doc """
  Stubs the GDG API response with the given events
  """
  def stub_gdg_response(events) when is_list(events) do

    results = Enum.map(events, fn event ->
      %{
        "id" => event.id,
        "title" => event.title,
        "url" => event.url,
        "start_date" => event.start_date,
        "end_date" => event.end_date
      }
    end)

    Bypass.expect(Helpers.bypass_gdg(), "GET", "/api/event", fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, Jason.encode!(%{
        "results" => results
      }))
    end)
  end
end

defmodule TestDateHelpers do
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

  def next_week do
    DateTime.utc_now()
    |> DateTime.add(7, :day)
    |> DateTime.truncate(:second)
    |> DateTime.to_naive()
  end

  def yesterday do
    DateTime.utc_now()
    |> DateTime.add(-1, :day)
    |> DateTime.truncate(:second)
    |> DateTime.to_naive()
  end

  def in_future_days(days) do
    DateTime.utc_now()
    |> DateTime.add(days, :day)
    |> DateTime.truncate(:second)
    |> DateTime.to_naive()
  end
end

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(MeetupBot.Repo, :manual)
