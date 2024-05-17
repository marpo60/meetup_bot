defmodule MeetupBot.Slack do
  def post(text) do
    webhook_url = System.get_env("WEBHOOK_URL")

    if webhook_url do
      Req.post!(webhook_url, body: text)
    end
  end

  def slackbot?(conn) do
    case Plug.Conn.get_req_header(conn, "user-agent") do
      ["Slackbot 1.0 (+https://api.slack.com/robots)"] -> true
      _ -> false
    end
  end

  def build_text([]) do
    """
    {
      "blocks": [
        {
          "type": "section",
          "text": {
            "type": "mrkdwn",
            "text": "No hay meetups agendados"
          }
        }
      ]
    }
    """
  end

  def build_text(meetups) do
    """
    {
      "blocks": [
        {
          "type": "section",
          "text": {"type": "mrkdwn", "text": "Los próximos meetups son:"}
        },
        {
          "type": "section",
          "text": {"type": "mrkdwn", "text": "#{to_bullet_list(meetups)}"}
        }
      ]
    }
    """
  end

  defp to_bullet_list(meetups) do
    Enum.map_join(meetups, "\n", fn meetup -> to_bullet_item(meetup) end)
  end

  defp to_bullet_item(meetup) do
    name = meetup.name |> String.replace("|> ", "")
    "• #{Calendar.strftime(meetup.datetime, "%-d %B - %H:%M")} - <#{meetup.event_url}|#{name}>"
  end
end
