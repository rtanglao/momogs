#!/usr/bin/env ruby
require 'rubygems'
require 'json'
require 'pp'
require 'time'
require 'date'
require 'mongo'
require 'base64'
require 'typhoeus'

MONGO_HOST = ENV["MONGO_HOST"]
raise(StandardError,"Set Mongo hostname in  ENV: 'MONGO_HOST'") if !MONGO_HOST
MONGO_PORT = ENV["MONGO_PORT"]
raise(StandardError,"Set Mongo port in  ENV: 'MONGO_PORT'") if !MONGO_PORT
MONGO_USER = ENV["MONGO_USER"]
raise(StandardError,"Set Mongo user in  ENV: 'MONGO_USER'") if !MONGO_USER
MONGO_PASSWORD = ENV["MONGO_PASSWORD"]
raise(StandardError,"Set Mongo user in  ENV: 'MONGO_PASSWORD'") if !MONGO_PASSWORD
GS_USER = ENV["GS_USER"]
raise(StandardError,"Set GS user in  ENV: 'GS_USER'") if !GS_USER
GS_PASSWORD = ENV["GS_PASSWORD"]
raise(StandardError,"Set Mongo user in  ENV: 'GS_PASSWORD'") if !GS_PASSWORD

db = Mongo::Connection.new(MONGO_HOST, MONGO_PORT.to_i).db("gs")
auth = db.authenticate(MONGO_USER, MONGO_PASSWORD)
if !auth
  raise(StandardError, "Couldn't authenticate, exiting")
  exit
end

topicsColl = db.collection("topics")

ARGF.each_line do |url|
  t = topicsColl.find_one({"at_sfn" => url.chomp}, :fields => ["at_sfn", "id"])
  if t
    reply_url = "https://api.getsatisfaction.com/topics/"+t["id"].to_s+"/replies.json"    
    result = Typhoeus::Request.post(reply_url,
              :username => GS_USER, :password => GS_PASSWORD, 
              :params => { "reply" => {"content" => "roland test reply time:"+Time.now.to_s}})
    pp result
  end
end
