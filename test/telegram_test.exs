defmodule TelegramTest do
  use ExUnit.Case, async: true

  alias MeetupBot.Telegram

  test "build_text" do
    meetups = [
      %{
        name: "Elixir |> Meetup",
        event_url: "http://example.com",
        datetime: ~N[2024-03-28 22:00:00],
        venue: "Company"
      }
    ]

    expected =
      """
      Los próximos meetups son:
      • Jue, 28 Mar - 22:00 - <a href="http://example.com">Elixir |> Meetup</a> @ Company
      """
      |> String.trim()

    assert expected == Telegram.build_text(meetups)
  end
end
