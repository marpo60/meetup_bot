defmodule MeetupBot.Router do
  use Plug.Router

  require OpenTelemetry.Tracer

  alias MeetupBot.MeetupCache
  alias MeetupBot.Slack
  alias OpenTelemetry.Tracer

  defmodule CacheBodyReader do
    def read_body(conn, opts) do
      {:ok, body, conn} = Plug.Conn.read_body(conn, opts)
      conn = update_in(conn.assigns[:raw_body], &[body | &1 || []])
      {:ok, body, conn}
    end
  end

  plug(Plug.Logger)

  plug(Plug.Parsers,
    parsers: [:urlencoded],
    body_reader: {CacheBodyReader, :read_body, []}
  )

  plug(:match)
  plug(:dispatch)

  get "/" do
    Tracer.with_span "meetup_bot.request.get" do
      send_resp(conn, 200, "Hello, World!")
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

  post "/" do
    Tracer.with_span "meetup_bot.request.post" do
      if Slack.slackbot?(conn) and Slack.verify_signature(conn) do
        Tracer.with_span "slack.request" do
          Tracer.set_attributes([
            {:command, conn.params["text"]},
            {:user_id, conn.params["user_id"]},
            {:user_name, conn.params["user_name"]},
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

  match _ do
    Tracer.with_span "meetup_bot.request" do
      send_resp(conn, 404, ":(")
    end
  end
end
