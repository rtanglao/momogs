#!/usr/bin/env ruby
require 'rubygems'
require 'json'
require 'pp'
require 'awesome_print'
require 'time'
require 'date'
require 'mongo'
require 'launchy'

MONGO_HOST = ENV["MONGO_HOST"]
raise(StandardError,"Set Mongo hostname in  ENV: 'MONGO_HOST'") if !MONGO_HOST
MONGO_PORT = ENV["MONGO_PORT"]
raise(StandardError,"Set Mongo port in  ENV: 'MONGO_PORT'") if !MONGO_PORT
MONGO_USER = ENV["MONGO_USER"]
raise(StandardError,"Set Mongo user in  ENV: 'MONGO_USER'") if !MONGO_USER
MONGO_PASSWORD = ENV["MONGO_PASSWORD"]
raise(StandardError,"Set Mongo user in  ENV: 'MONGO_PASSWORD'") if !MONGO_PASSWORD

db = Mongo::Connection.new(MONGO_HOST, MONGO_PORT.to_i).db("gs")
auth = db.authenticate(MONGO_USER, MONGO_PASSWORD)
if !auth
  raise(StandardError, "Couldn't authenticate, exiting")
  exit
end

topicsColl = db.collection("topics")

if ARGV.length < 2
  puts "usage: #{$0} yyyy mm dd"
  exit
end

metrics_start = Time.utc(ARGV[0], ARGV[1], ARGV[2], 0, 0)
metrics_stop = Time.utc(ARGV[0], ARGV[1], ARGV[2], 23, 59, 59)
metrics_stop += 1
query = {"created_at" => {"$gte" => metrics_start, "$lt" => metrics_stop}}
query["status"]  = { "$nin" => ["complete", "rejected"]} 
query["tags_str"] = { "$not" => Regexp.new("rtprocessed") } 

topic_urls = []
topicsColl.find(query,:fields => ["at_sfn", "created_at", "tags_str", "status"]).sort(
     [["created_at", Mongo::ASCENDING]]).each do |t| 
  topic_urls.push(t["at_sfn"])
end

20.times do
  index = rand topic_urls.length
  Launchy.open(topic_urls[index], options = {} )  
  $stderr.puts(topic_urls[index])
  topic_urls.delete_at(index)
end 
