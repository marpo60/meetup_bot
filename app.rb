# encoding: utf-8
require 'net/http'
require 'json'
require 'cgi'
require 'time'
require 'singleton'

class App
  include Singleton

  GROUP_NAMES = [
   'ember-montevideo',
   'ReactJS-Uruguay',
   'Angular-MVD',
   'montevideojs',
   'Front-end-MVD',
   'Elixir-Montevideo',
   'Montevideo-Web-Developers',
   'Rust-Uruguay',
   'py-mvd',
   'Loop-Talks',
   'Laravel-UY',
   'Montevideo-Vue-JS-Meetup',
   'NahualUY',
   'AETERNITY-URUGUAY',
   'Odoo-ERP-Uruguay',
   'mujeresituy',
   'Developer-Circle-montevideo',
   'IBM-Developers-Montevideo',
  ]

  def init
    fetch_group_ids
  end

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

  def post_to_slack
    webhook_url = ENV["WEBHOOK_URL"]

    if webhook_url
      uri = URI.parse(webhook_url)

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      request = Net::HTTP::Post.new(
        uri.request_uri,
        'Content-Type' => 'application/json'
      )
      request.body = list_message

      response = http.request(request)
      puts response.body
    else
      puts "No Webhook url"
    end
  end

  def verify_signature(request)
    request["x-slack-signature"] == calculate_signature(request)
  end

  private

  def calculate_signature(request)
    timestamp = request["x-slack-request-timestamp"]
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

  def fetch_upcoming_meetups
    query_string = URI.encode_www_form(
      group_id: fetch_group_ids.join(","),
      only: "time,group.name,event_url",
      status: "upcoming",
      time: ",1m"
    )
    uri = URI("https://api.meetup.com/2/events?#{query_string}")
    res = Net::HTTP.get_response(uri)

    JSON.parse(res.body)["results"]
  end

  def fetch_group_ids
    @group_ids ||= begin
      GROUP_NAMES.map do |name|
        uri = URI("https://api.meetup.com/#{name}")
        res = Net::HTTP.get_response(uri)
        JSON.parse(res.body)["id"]
      end
    end
  end
end
