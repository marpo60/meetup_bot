defmodule MeetupBot.MeetupFormatter do
  def to_bullet_list(meetups, link_formatter) do
    Enum.map_join(meetups, "\n", fn meetup -> to_bullet_item(meetup, link_formatter) end)
  end

  def to_bullet_item(meetup, link_formatter) do
    datetime =
      Calendar.strftime(
        meetup.datetime,
        "%a, %-d %b - %H:%M",
        abbreviated_month_names: fn month ->
          {"Ene", "Feb", "Mar", "Abr", "May", "Jun", "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"}
          |> elem(month - 1)
        end,
        abbreviated_day_of_week_names: fn day_of_week ->
          {"Lun", "Mar", "Mie", "Jue", "Vie", "Sab", "Dom"} |> elem(day_of_week - 1)
        end
      )

    link = link_formatter.(meetup.name, meetup.event_url)

    venue = if(venue = Map.get(meetup, :venue), do: " @ #{venue}", else: "")

    "• #{datetime} - #{link}#{venue}"
  end
end
