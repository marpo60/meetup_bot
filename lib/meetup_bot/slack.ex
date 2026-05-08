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
    datetime =
      Calendar.strftime(
        meetup.datetime,
        "%a, %-d %b - %H:%M",
        abbreviated_month_names: fn month ->
          {"Ene", "Feb", "Mar", "Abr", "May", "Jun", "Jul", "Ago", "Sep", "Oct", "Nov", "Dec"}
          |> elem(month - 1)
        end,
        abbreviated_day_of_week_names: fn day_of_week ->
          {"Lun", "Mar", "Mie", "Jue", "Vie", "Sab", "Dom"} |> elem(day_of_week - 1)
        end
      )

    event_with_link = "<#{meetup.event_url}|#{escaped_text(meetup.name)}>"

    venue =
      if meetup.venue do
        "@ #{meetup.venue}"
      end

    "• #{datetime} - #{event_with_link} #{venue}"
  end

  defp escaped_text(text) do
    # https://api.slack.com/reference/surfaces/formatting#escaping
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
  end
end
