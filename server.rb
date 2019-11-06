# encoding: utf-8
require 'webrick'
require 'net/http'
require 'json'
require 'cgi'
require './app'


class AuthRedirectServlet < WEBrick::HTTPServlet::AbstractServlet
  def do_GET(request, response)
    query_string = URI.encode_www_form(
      code: request.query["code"],
      client_id: ENV["CLIENT_ID"],
      client_secret: ENV["CLIENT_SECRET"],
      redirect_uri: ENV["REDIRECT_URI"]
    )
    uri = URI("https://slack.com/api/oauth.access?#{query_string}")
    res = JSON.parse(Net::HTTP.get_response(uri).body)
    puts res
    $stdout.flush
    if res["ok"]
      response.body = "Exito!"
    else
      response.body = res.to_s
    end
  end
end

class SlackCommandServlet < WEBrick::HTTPServlet::AbstractServlet
  def do_POST(request, response)
    if App.instance.verify_signature(request)
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
  end

  def do_GET(request, response)
    response.body = "200 OK"
  end
end

server = WEBrick::HTTPServer.new(:Port => 8080)
server.mount '/auth/redirect', AuthRedirectServlet
server.mount '/', SlackCommandServlet

trap("INT") {server.shutdown}
App.instance.init
server.start
