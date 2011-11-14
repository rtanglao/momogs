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

f = File.open("stoplist.txt") or die "Unable to open stoplist.txt..."
stoplist = [] 
f.each_line {|line| stoplist.push line.chomp}
# find active topics that were updated in the time period
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
word_list = word_list.sort {|a,b| a[1]<=>b[1]}
stoplist.each{|stop|word_list.delete_if{|w|w[0].include?(stop)}}
pp word_list
stop_list_file = File.new("stoplist."+ARGV[0]+ARGV[1]+ARGV[2]+ARGV[3]+ARGV[4]+ARGV[5]+"-words.txt", "w")

word_list.each {|row|stop_list_file.puts"#{row[0]}" }
stop_list_file.close
