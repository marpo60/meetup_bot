# encoding: utf-8
require 'webrick'
require 'net/http'
require 'json'
require 'cgi'
require './app'

server = WEBrick::HTTPServer.new(:Port => 8080)
server.mount_proc('/') {|request, response|
  if request.path == "/auth/redirect"
    query_string = URI.encode_www_form(
      code: request.query["code"],
      client_id: ENV["CLIENT_ID"],
      client_secret: ENV["CLIENT_SECRET"],
      redirect_uri: ENV["REDIRECT_URI"]
    )
    uri = URI("https://slack.com/api/oauth.access?#{query_string}")
    res = JSON.parse(Net::HTTP.get_response(uri).body)
    if res["ok"]
      response.body = "Exito!"
    else
      response.body = res.to_s
    end
  end

  # Slack Command
  if request.path == "/" && request.header["x-slack-signature"] && App.instance.verify_signature(request)
    args = CGI.parse(request.body)["text"]

    if args == ["list"]
      response.content_type = "application/json"
      response.body = App.instance.list_message
    else
      response.body = "Comando incorrecto"
    end
  else
    response.body = "200 OK"
  end
}
trap("INT") {server.shutdown}
server.start
