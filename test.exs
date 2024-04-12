Mix.install([
  {:bandit, ">= 0.0.0"},
  :req
])

ExUnit.start()

Code.require_file("slack.exs")

defmodule SlackTest do
  use ExUnit.Case, async: true

  use Plug.Test

  test "verify_signature" do
    # From Slack Docs
    raw_body = "token=xyzz0WbapA4vBCDEFasx0q6G&team_id=T1DC2JH3J&team_domain=testteamnow&channel_id=G8PSS9T3V&channel_name=foobar&user_id=U2CERLKJA&user_name=roadrunner&command=%2Fwebhook-collect&text=&response_url=https%3A%2F%2Fhooks.slack.com%2Fcommands%2FT1DC2JH3J%2F397700885554%2F96rGlfmibIGlgcZRskXaIFfN&trigger_id=398738663015.47445629121.803a0bc887a14d10d2c447fce8b6703c"

    x_slack_signature = "v0=a2114d57b48eac39b9ad189dd8316235a7b4a8d21a10bd27519666489c69b503"
    x_slack_request_timestamp = "1531420618"
    signing_secret = "8f742231b10e8888abcd99yyyzzz85a5"

    conn = conn(:get, "/", "")
           |> put_req_header("x-slack-signature", x_slack_signature)
           |> put_req_header("x-slack-request-timestamp", x_slack_request_timestamp)
           |> assign(:raw_body, raw_body)

    assert Slack.verify_signature(conn, signing_secret)
  end

  test "build_text" do
    meetups = [%{
      name: "Elixir |> Meetup",
      event_url: "http://example.com",
      datetime: ~N[2024-03-28 22:00:00]
    }]

    expected = """
    {
      "blocks": [
        {
          "type": "section",
          "text": {"type": "mrkdwn", "text": "Los próximos meetups son:"}
        },
        {
          "type": "section",
          "text": {"type": "mrkdwn", "text": "• 28 March - 22:00 - <http://example.com|Elixir Meetup>"}
        }
      ]
    }
    """
    assert expected == Slack.build_text(meetups)
  end
end
