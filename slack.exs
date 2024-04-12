defmodule Slack do
  def post(text) do
    webhook_url = System.get_env("WEBHOOK_URL")

    Req.post!(webhook_url, body: text)
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
    Enum.map_join(meetups, "\n", fn(meetup) -> to_bullet_item(meetup) end)
  end

  defp to_bullet_item(meetup) do
    name = meetup.name |> String.replace("|> ", "")
    "• #{Calendar.strftime(meetup.datetime, "%-d %B - %H:%M")} - <#{meetup.event_url}|#{name}>"
  end
end
