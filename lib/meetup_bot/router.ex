defmodule MeetupBot.Router do
  use Plug.Router

  require OpenTelemetry.Tracer

  alias MeetupBot.MeetupCache
  alias MeetupBot.MeetupCalendar
  alias MeetupBot.Slack
  alias OpenTelemetry.Tracer

  plug(Plug.Logger)

  plug(Plug.Parsers,
    parsers: [:urlencoded],
    body_reader: {SlackRequest.BodyReader, :read_body, []}
  )

  plug(:match)
  plug(:dispatch)

  get "/" do
    Tracer.with_span "meetup_bot.request.get" do
      template = """
        <title>OWU.UY - MeetupBot</title>
        <h1>Próximos meetups</h1>
        <ul>
          <%= for meetup <- meetups do %>
            <li>
              <%= Calendar.strftime(meetup.datetime, "%-d %B - %H:%M") %> -
              <%= meetup.name %>;
              <a href="<%= meetup.event_url %>">
                <%= meetup.title %>
              </a>
            </li>
          <% end %>
        </ul>
      """

      html = EEx.eval_string(template, meetups: MeetupCache.values())

      conn
      |> put_resp_content_type("text/html")
      |> send_resp(200, html)
    end
  end

  get "/auth/redirect" do
    Tracer.with_span "meetup_bot.request.get" do
      body = [
        code: conn.params["code"],
        client_id: System.fetch_env!("CLIENT_ID"),
        client_secret: System.fetch_env!("CLIENT_SECRET"),
        redirect_uri: System.fetch_env!("REDIRECT_URL")
      ]

      response = Req.post!("https://slack.com/api/oauth.access", form: body)

      # Hacky way to get the webhooks
      IO.inspect(response, label: "Response from OAuth")

      send_resp(conn, 200, "OK")
    end
  end

  get "/calendar.ics" do
    Tracer.with_span "meetup_bot.request.get" do
      body = MeetupCache.values()
             |> MeetupCalendar.to_ics()

      conn
      |> put_resp_content_type("text/calendar")
      |> send_resp(200, body)
    end
  end

  post "/" do
    Tracer.with_span "meetup_bot.request.post" do
      if Slack.slackbot?(conn) and
         SlackRequest.valid_request?(conn, secret: System.fetch_env!("SIGNING_SECRET")) do
        Tracer.with_span "slack.request" do
          Tracer.set_attributes([
            {:command, conn.params["text"]},
            {:user_id, conn.params["user_id"]},
            {:user_name, conn.params["user_name"]},
            {:team_id, conn.params["team_id"]},
            {:team_domain, conn.params["team_domain"]},
            {:channel_id, conn.params["channel_id"]},
            {:channel_name, conn.params["channel_name"]}
          ])

          if conn.params["text"] == "list" do
            meetups = MeetupCache.values()
            text = Slack.build_text(meetups)

            conn
            |> put_resp_content_type("application/json")
            |> send_resp(200, text)
          else
            Tracer.set_status(:error, "wrong command")

            send_resp(conn, 200, "Comando incorrecto")
          end
        end
      else
        send_resp(conn, 200, "200 OK")
      end
    end
  end

  get "/json" do
    Tracer.with_span "meetup_bot.request.get" do
      meetups = MeetupCache.values()

      conn
      |> put_resp_content_type("application/json")
      |> send_resp(200, Jason.encode!(%{meetups: meetups}))
    end
  end

  match _ do
    Tracer.with_span "meetup_bot.request" do
      send_resp(conn, 404, ":(")
    end
  end
end
