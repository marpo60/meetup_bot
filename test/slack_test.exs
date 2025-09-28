defmodule SlackTest do
  use ExUnit.Case, async: true
  import Plug.Test

  alias MeetupBot.Slack

  test "build_text" do
    meetups = [
      %{
        name: "Elixir |> Meetup",
        event_url: "http://example.com",
        datetime: ~N[2024-03-28 22:00:00],
        venue: "Company"
      }
    ]

    expected = """
    {
      "blocks": [
        {
          "type": "section",
          "text": {"type": "mrkdwn", "text": "Los próximos meetups son:"}
        },
        {
          "type": "section",
          "text": {"type": "mrkdwn", "text": "• Jue, 28 Mar - 22:00 - <http://example.com|Elixir |&gt; Meetup> @ Company"}
        }
      ]
    }
    """

    assert expected == Slack.build_text(meetups)
  end
end
