defmodule MeetupBot.Telegram do
  require Logger

  def post(text) do
    token = System.get_env("TELEGRAM_BOT_TOKEN")
    chat_id = System.get_env("TELEGRAM_CHAT_ID")

    if token && chat_id do
      # https://core.telegram.org/bots/api#sendmessage
      url = "https://api.telegram.org/bot#{token}/sendMessage"

      Req.post!(url,
        json: %{
          chat_id: chat_id,
          text: text,
          parse_mode: "HTML",
          link_preview_options: %{
            is_disabled: true
          }
        }
      )
    else
      Logger.warning("Telegram: TELEGRAM_BOT_TOKEN or TELEGRAM_CHAT_ID not configured")
      :skip
    end
  end

  def build_text([]) do
    "No hay meetups agendados"
  end

  def build_text(meetups) do
    header = "Los próximos meetups son:\n"
    meetups_text = MeetupBot.MeetupFormatter.to_bullet_list(meetups, &telegram_link_formatter/2)
    header <> meetups_text
  end

  defp telegram_link_formatter(name, url) do
    "<a href=\"#{url}\">#{name}</a>"
  end
end
