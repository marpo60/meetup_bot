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
    end
  end

  def build_text([]) do
    "No hay meetups agendados"
  end

  def build_text(meetups) do
    header = "Los próximos meetups son:\n"
    meetups_text = Enum.map_join(meetups, "\n", fn meetup -> to_bullet_item(meetup) end)
    header <> meetups_text
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

    event_with_link = "<a href=\"#{meetup.event_url}\">#{meetup.name}</a>"

    venue =
      if meetup.venue do
        "@ #{meetup.venue}"
      end

    "• #{datetime} - #{event_with_link} #{venue}"
  end
end
