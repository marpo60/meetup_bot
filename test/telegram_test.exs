defmodule MeetupBot.TelegramIntegrationTest do
  use ExUnit.Case, async: true

  describe "build_text/1" do
    test "construye texto con lista vacía" do
      text = MeetupBot.Telegram.build_text([])
      assert text == "No hay meetups agendados"
    end

    test "construye texto correctamente con meetups" do
      meetups = [
        %{
          name: "Elixir Meetup",
          datetime: ~U[2026-03-25 18:00:00Z],
          event_url: "https://meetup.com/elixir-montevideo",
          venue: "Mimiquate"
        }
      ]

      text = MeetupBot.Telegram.build_text(meetups)

      assert text ==
               "Los próximos meetups son:\n• Mie, 25 Mar - 18:00 - <a href=\"https://meetup.com/elixir-montevideo\">Elixir Meetup</a> @ Mimiquate"
    end

    test "formatea múltiples meetups correctamente" do
      meetups = [
        %{
          name: "Elixir Meetup",
          datetime: ~U[2026-03-25 18:00:00Z],
          event_url: "https://meetup.com/elixir-montevideo",
          venue: "Mimiquate"
        },
        %{
          name: "Phoenix Workshop",
          datetime: ~U[2026-04-01 19:00:00Z],
          event_url: "https://meetup.com/phoenix",
          venue: "1950Labs"
        }
      ]

      text = MeetupBot.Telegram.build_text(meetups)

      assert text =~
               "Los próximos meetups son:\n• Mie, 25 Mar - 18:00 - <a href=\"https://meetup.com/elixir-montevideo\">Elixir Meetup</a> @ Mimiquate\n• Mie, 1 Abr - 19:00 - <a href=\"https://meetup.com/phoenix\">Phoenix Workshop</a> @ 1950Labs"
    end

    test "formatea 3 meetups con diferente información" do
      meetups = [
        %{
          name: "Uruguay Javascript Meetup Group",
          datetime: ~U[2026-03-17 19:00:00Z],
          event_url: "https://meetup.com/uy-javascript",
          venue: "Mimiquate"
        },
        %{
          name: "Python Montevideo",
          datetime: ~U[2026-03-19 19:00:00Z],
          event_url: "https://meetup.com/py-mvd",
          venue: "Xmartlabs"
        },
        %{
          name: "Elixir |> Montevideo",
          datetime: ~U[2026-03-24 19:00:00Z],
          event_url: "https://meetup.com/elixir-mvd",
          venue: "Mimiquate"
        }
      ]

      text = MeetupBot.Telegram.build_text(meetups)

      assert text =~ "Uruguay Javascript Meetup Group"
      assert text =~ "Python Montevideo"
      assert text =~ "Elixir |> Montevideo"
      assert text =~ "Mar, 17 Mar - 19:00"
      assert text =~ "Jue, 19 Mar - 19:00"
      assert text =~ "Mar, 24 Mar - 19:00"
      assert text =~ "@ Mimiquate"
      assert text =~ "@ Xmartlabs"
    end

    test "formatea meetup sin venue" do
      meetups = [
        %{
          name: "Tech Meetup",
          datetime: ~U[2026-03-20 10:00:00Z],
          event_url: "https://meetup.com/tech"
        }
      ]

      text = MeetupBot.Telegram.build_text(meetups)

      assert text =~ "Vie, 20 Mar - 10:00"
      refute text =~ "@"
    end

    test "formatea meetup con caracteres especiales en el nombre" do
      meetups = [
        %{
          name: "Tech & Coffee",
          datetime: ~U[2026-03-20 10:00:00Z],
          event_url: "https://meetup.com/tech-coffee",
          venue: "Mimiquate"
        }
      ]

      text = MeetupBot.Telegram.build_text(meetups)

      assert text =~
               "• Vie, 20 Mar - 10:00 - <a href=\"https://meetup.com/tech-coffee\">Tech & Coffee</a> @ Mimiquate"
    end

    test "formatea fecha con día y mes simples" do
      meetups = [
        %{
          name: "Simple Meetup",
          datetime: ~U[2026-01-05 08:00:00Z],
          event_url: "https://meetup.com/simple"
        }
      ]

      text = MeetupBot.Telegram.build_text(meetups)

      assert text =~ "Lun, 5 Ene - 08:00"
    end
  end
end
