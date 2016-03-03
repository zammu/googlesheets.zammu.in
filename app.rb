#!/usr/bin/env ruby

require 'sinatra'
require 'redis'
require 'sinatra/json'
#require 'sinatra/reloader'

SheetError = Class.new(StandardError)
class Sheet
  require 'json'
  require 'csv'
  require 'typhoeus'
  require 'securerandom'

  attr_accessor :id, :url, :id_column

  def initialize(id:, url:, id_column:)
    self.id, self.url, self.id_column = id || SecureRandom.urlsafe_base64, url, id_column
  end

  URLS_HASH = "gs:urls" # { "https://www..." => "keyfoo", ... }
  TABLE_HASH = "gs:sheets" # { "keyfoo" => { "url": "https://www...", "id": "..", ... }

  def save
    Redis.current.hset(URLS_HASH, url, id)
    Redis.current.hset(TABLE_HASH, id, {u: url, i: id_column}.to_json)
  end

  def get_row(row_id)
    rows = get_csv
    return rows if rows.is_a?(SheetError)
    rows.find{|x| x[id_column] == row_id}
  end

  TIMEOUT_SECONDS = 3
  def get_csv
    r = Typhoeus.get(url, followlocation: true, timeout: TIMEOUT_SECONDS)
    return SheetError.new(r.return_code) if !r.success?
    CSV.parse(r.body, headers: true).map{|x| x.to_h}
  end

  def to_s
    "Sheet: <id: #{id}, id_column: #{id_column}, url: #{url}>"
  end

  class << self
    def find_id_for_url(url)
      Redis.current.hget(Sheet::URLS_HASH, url)
    end

    def find_by_id(id)
      d = Redis.current.hget(Sheet::TABLE_HASH, id)
      return nil if !d
      j = JSON.parse(d)
      Sheet.new(id: id, id_column: j['i'], url: j['u'])
    end
  end
end

#puts Redis.current.hgetall(Sheet::TABLE_HASH)
#puts Sheet.find_id_for_url "https://docs.google.com/spreadsheets/d/19CgLN5_XWXk4AEuho8WlXaec6t3inuq5-7-6QhJUGyU/pub?gid=1837566559&single=true&output=csv"
#puts Sheet.find_by_id("mXIMy_z7EACrJeeUIYkiAw")
#s = Sheet.new(id: nil, id_column: "autoid", url: "https://docs.google.com/spreadsheets/d/19CgLN5_XWXk4AEuho8WlXaec6t3inuq5-7-6QhJUGyU/pub?gid=1837566559&single=true&output=csv")
#puts s.get_row('2bf1fdad-ce5a-47e9-88b3-b80ffe1ed60e')
#puts s.save

# make sure redis is up
puts "REDIS: PING <-> #{Redis.current.ping}"

set :port, 3030

#TODO: make this use the public/index.html page
get '/' do
  erb :index
end

post '/' do
  url = params[:url]
  if existing_id = Sheet.find_id_for_url(url)
    return "EXISTS AS ID: https://googlesheets.zammu.in/sheet/#{existing_id}/:row_id"
  end

  sheet = Sheet.new(id: nil, url: url, id_column: params[:id_column])
  sheet.save

  "CREATED ID: https://googlesheets.zammu.in/sheet/#{sheet.id}/:row_id"
end

get "/sheet/:id/:row_id" do
  sheet = Sheet.find_by_id(params[:id])
  if !sheet
    status 404
    return json(error: "sheet not found")
  end
  row = sheet.get_row(params[:row_id])
  if !row
    status 404
    return json(error: "row not found in sheet")
  end
  if row.is_a?(SheetError)
    status 400
    return json(error: row.message)
  end
  json row
end
