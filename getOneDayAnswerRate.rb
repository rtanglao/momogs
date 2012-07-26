#!/usr/bin/env ruby
require 'rubygems'
require 'json'
require 'pp'
require 'date'
require 'time'
require 'mongo'
 
if ARGV.length < 6
  puts "usage: #{$0} yyyy mm dd yyyy mmm dd"
  exit
end

metrics_start = Time.utc(ARGV[0], ARGV[1], ARGV[2], 0, 0)
metrics_stop = Time.utc(ARGV[3], ARGV[4], ARGV[5], 23, 59)

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

new_topics_per_day=[]
topicsColl.find({"created_at" => {"$gte" => metrics_start, "$lte" => metrics_stop}},
                :fields => ["at_sfn", "id", "created_at", "reply_array", "author"]).sort(
                            [["created_at", Mongo::ASCENDING]]).each do |t|
  url = t["at_sfn"]
  created_at = t["created_at"]
  $stderr.printf("NEW TOPIC id:%d, url:%s, created_at:%s\n", t["id"],url, created_at)
  created_at_index = created_at.strftime("%-m/%-d/%y")
  element = new_topics_per_day.detect{|d| d["date"] == created_at_index}
  if element
    element["numquest"] += 1
  else
    element = new_topics_per_day.push({"date" => created_at_index, "numquest" => 1, "numans" => 0}).last    
  end
  op = t["author"]["canonical_name"]
  reply_metrics_start = created_at
  reply_metrics_stop = reply_metrics_start + (24 * 3600)
  t["reply_array"].each do |r|
    reply_created_at = r["created_at"]
    if r["author"]["canonical_name"] != op &&
        ((reply_created_at <=> reply_metrics_start) >= 0) && 
        ((reply_created_at <=> reply_metrics_stop) <= 0)
      element["numans"] += 1
      break
    end
  end
end

print("date, numans, numquest, answer-rate\n")
new_topics_per_day.each do |num_new_topics_per_date|
  numans = num_new_topics_per_date["numans"]
  numquest = num_new_topics_per_date["numquest"]
  answer_rate = Float(numans)/Float(numquest) * 100.0
  printf("%s,%d,%d,%f\n",num_new_topics_per_date["date"], numans, numquest, answer_rate)
end
