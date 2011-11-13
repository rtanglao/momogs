#!/usr/bin/env ruby
require 'rubygems'
require 'json'
require 'net/http'
require 'pp'
require 'time'
require 'date'
require 'mongo'
require 'engtagger'
require 'sanitize'

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

metrics_start = Time.utc(ARGV[0], ARGV[1], ARGV[2], 0, 0)
metrics_stop =  Time.utc(ARGV[3], ARGV[4], ARGV[5], 23, 59)

# find active topics that were updated in the time period
# then calculate:
#   trending tags, mail providers, ISPs and proper nounds
# provider_mention_counts = [{"count" => 0, "link_html" => []}] * providers.length
subject_content_reply = ''
topicsColl.find({"last_active_at" =>  
                  {"$gte" => metrics_start, "$lte" => metrics_stop }},
                  :fields => ["last_active_at", "fulltext"]
                ).sort([["last_active_at", Mongo::ASCENDING]]).each do |t| 
  subject_content_reply = subject_content_reply + t["fulltext"] + " " 
end

tgr = EngTagger.new
words = Sanitize.clean(subject_content_reply)
word_list = tgr.get_words(words)
pp word_list.sort {|a,b| a[1]<=>b[1]}
