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

new_topics_per_day={}
topicsColl.find({"created_at" => {"$gte" => metrics_start, "$lte" => metrics_stop}
                }, :fields => ["at_sfn", "id", "created_at"]).sort([["created_at", Mongo::ASCENDING]]).each do |t|
  url = t["at_sfn"]
  created_at = t["created_at"]
  $stderr.printf("NEW TOPIC id:%d, url:%s, created_at:%s\n", t["id"],url, created_at)
  created_at_index = created_at.strftime("%Y%m%d")
  if new_topics_per_day.has_key?(created_at_index)
    new_topics_per_day[created_at_index] += 1
  else
    new_topics_per_day[created_at_index] = 1
  end
end

resolved_topics_per_day={}
topicsColl.find({"created_at" => {"$lte" => metrics_stop},
                "status" => "complete"}, 
                :fields => ["created_at", "at_sfn", "id", "last_active_at"]).sort([["last_active_at", Mongo::ASCENDING]]).each do |t|
  url = t["at_sfn"]
  last_active_at = t["last_active_at"]
  if ((last_active_at <=> metrics_start) < 0) || ((last_active_at <=> metrics_stop) > 0)
    next
  end
  $stderr.printf("RESOLVED TOPIC id:%d, url:%s, last_active_at:%s\n", t["id"],url, last_active_at)
  last_active_at_index = last_active_at.strftime("%Y%m%d")
  if resolved_topics_per_day.has_key?(last_active_at_index)
    resolved_topics_per_day[last_active_at_index] += 1
  else
    resolved_topics_per_day[last_active_at_index] = 1
  end
end

print("New topics per day****\n")
new_topics_per_day = new_topics_per_day.sort
new_topics_per_day.each {|date,num_new_topics_per_date|printf("date:%s #new support topics:%d\n",date, num_new_topics_per_date)}
printf("Topics resolved per day****\n")
resolved_topics_per_day = resolved_topics_per_day.sort
resolved_topics_per_day.each {|date,num_resolved_topics_per_date|printf("date:%s #resolved support topics:%d\n",date, num_resolved_topics_per_date)}
