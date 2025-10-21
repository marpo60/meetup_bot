defmodule MeetupBot.ObanWeb.Router do
  @moduledoc """
  Plug router for Oban Web dashboard endpoints.
  """

  use Plug.Router
  alias MeetupBot.ObanWeb

  plug(Plug.Logger)
  plug(Plug.Parsers, parsers: [:json], json_decoder: Jason)
  plug(:match)
  plug(:dispatch)

  # Dashboard home page
  get "/" do
    ObanWeb.dashboard(conn, conn.params)
  end

  # Job detail page
  get "/jobs/:id" do
    job_id = String.to_integer(id)
    ObanWeb.job_detail(conn, job_id)
  end

  # Job actions endpoint (retry, cancel, delete)
  post "/jobs/action" do
    action = conn.body_params["action"]
    job_ids = conn.body_params["job_ids"]

    ObanWeb.job_action(conn, action, job_ids)
  end

  # Queue actions endpoint (pause, resume, scale)
  post "/queues/action" do
    action = conn.body_params["action"]
    queue = conn.body_params["queue"]
    params = conn.body_params

    ObanWeb.queue_action(conn, action, queue, params)
  end

  # Catch all
  match _ do
    send_resp(conn, 404, "Not Found")
  end
end
