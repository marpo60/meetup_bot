# encoding: utf-8
require 'webrick'
require 'net/http'
require 'json'
require 'cgi'
require 'singleton'

class App
  include Singleton

  GROUPS_ID = [
   12641372, # ember-montevideo
   20489638, # ReactJS-Uruguay
   18755240, # Angular-MVD
   5844892,  # montevideojs
   18200397, # Front-end-MVD
   19945900, # Elixir |> Montevideo
   28497632, # Montevideo-Web-Developers
   17631212, # Rust-Uruguay
   5946782,  # py-mvd
   31611165, # Loop-Talks
   18188651, # Laravel-UY
  ].join(",")

  def list_message
    meetups = fetch_upcoming_meetups

    %Q({
      "blocks": [
        {
          "type": "section",
          "text": {"type": "mrkdwn", "text": "Los próximos meetups son:"}
        },
        {
          "type": "section",
          "text": {"type": "mrkdwn", "text": "#{bullet_list(meetups)}"}
        }
      ]
    })
  end

  def verify_signature(request)
    request["x-slack-signature"] == calculate_signature(request)
  end

  private

  def calculate_signature(request)
    timestamp = request.header["x-slack-request-timestamp"].first
    base_string_for_signature = "v0:#{timestamp}:#{request.body}"

    hex = OpenSSL::HMAC.hexdigest("SHA256", ENV["SIGNING_SECRET"], base_string_for_signature)
    "v0=#{hex}"
  end

  def bullet_list(meetups)
    meetups.map{ |meetup| to_bullet_item(meetup) }.join("\n")
  end

  def to_bullet_item(meetup)
    time = Time.strptime(meetup['time'].to_s, '%Q').localtime("-03:00")
    "• #{time.strftime('%e %B - %H:%M')} - #{meetup['group']['name']} - #{meetup['event_url']}"
  end

  def fetch_upcoming_meetups()
    query_string = URI.encode_www_form(
      group_id: GROUPS_ID,
      only: "time,group.name,event_url",
      status: "upcoming",
      time: ",1m"
    )
    uri = URI("https://api.meetup.com/2/events?#{query_string}")
    res = Net::HTTP.get_response(uri)

    JSON.parse(res.body)["results"]
  end
end

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
