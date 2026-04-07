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
          "text": {"type": "mrkdwn", "text": "#{MeetupBot.MeetupFormatter.to_bullet_list(meetups, &slack_link_formatter/2)}"}
        }
      ]
    }
    """
  end

  defp slack_link_formatter(name, url) do
    # https://api.slack.com/reference/surfaces/formatting#escaping
    escaped_name =
      name
      |> String.replace("&", "&amp;")
      |> String.replace("<", "&lt;")
      |> String.replace(">", "&gt;")

    "<#{url}|#{escaped_name}>"
  end
end
