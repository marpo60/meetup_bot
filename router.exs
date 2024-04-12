defmodule Router do
  use Plug.Router

  plug(:match)
  plug(:dispatch)

  get "/" do
    send_resp(conn, 200, "Hello, World!")
  end

  get "/auth/redirect" do
    send_resp(conn, 200, "OK")
  end

  post "/" do
    send_resp(conn, 200, "200 OK")
  end

  match _ do
    send_resp(conn, 404, ":(")
  end
end

