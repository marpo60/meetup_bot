defmodule Slack do
  def post(text) do
    webhook_url = System.get_env("WEBHOOK_URL")

    Req.post!(webhook_url, body: text)
  end

  def slackbot?(conn) do
    case Plug.Conn.get_req_header(conn, "user-agent") do
      ["Slackbot 1.0 (+https://api.slack.com/robots)"] -> true
      _ -> false
    end
  end

  def verify_signature(conn) do
    signing_secret = System.get_env("SIGNING_SECRET")
    verify_signature(conn, signing_secret)
  end

  def verify_signature(conn, signing_secret) do
    raw_body = conn.assigns[:raw_body]
    [x_slack_signature] = Plug.Conn.get_req_header(conn, "x-slack-signature")
    [x_slack_request_timestamp] = Plug.Conn.get_req_header(conn, "x-slack-request-timestamp")

    to_sign = "v0:#{x_slack_request_timestamp}:#{raw_body}"
    actual_signature = :crypto.mac(:hmac, :sha256, signing_secret, to_sign)
    |> Base.encode16(case: :lower)

    x_slack_signature == "v0=#{actual_signature}"
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
