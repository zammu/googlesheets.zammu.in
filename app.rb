#!/usr/bin/env ruby

#require 'sinatra'
require 'redis'
#require 'sinatra/reloader'

require 'json'
require 'csv'
require 'typhoeus'
class Sheet
  attr_accessor :id, :url, :headers

  def initialize(id:, url:, headers:)
    self.id, self.url, self.headers = id, url, headers
  end

  URLS_HASH = "gs:urls" # { "https://www..." => "keyfoo", ... }
  TABLE_HASH = "gs:sheets" # { "keyfoo" => { "url": "https://www...", "id": "..", ... }

  def save
    Redis.current.hset(TABLE_HASH, id, {u: url, h: headers}.to_json)
  end

  def get_row(row_id)
  end

  def get_csv
    CSV.parse(Typhoeus.get(url, followlocation: true).body, headers: headers)
  end

  class << self
    def find_id_for_url(url)
    end

    def find_by_id(id)
    end
  end
end

s = Sheet.new(id: "x", headers: "foo, bar", url: "https://docs.google.com/spreadsheets/d/19CgLN5_XWXk4AEuho8WlXaec6t3inuq5-7-6QhJUGyU/pub?gid=1837566559&single=true&output=csv")
puts s.get_csv

exit

# make sure redis is up
puts "REDIS: PING <-> #{Redis.current.ping}"

set :port, 3030

#TODO: make this use the public/index.html page
get '/' do
  erb :index
end

def find_id(url)
  Redis.current.hget(URLS_HASH, url)
end

def find_url(id)
  Redis.current.hget(KEYS_HASH, id)
end


post '/' do
  url = params[:url]
  if existing_id = find_id(url)
    return "ID: #{existing_id}"
  end

  id = SecureRandom.urlsafe_base64
  Redis.current.hset URLS_HASH, url, id
  Redis.current.hset KEYS_HASH, id, url

  "ID: #{id}"
end

get "/sheet/:id/:row_id" do
  url = find_url(params[:id])
  return "sheet not found" if !url
  data = Typhoeus.get(url, followlocation: true)
end
