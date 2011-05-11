#!/usr/bin/env ruby
require 'rubygems'
require 'json'
require 'pp'
require 'time'
require 'date'
require 'mongo'

if ARGV.length < 6
  puts "usage: #{$0} yyyy mm dd yyyy mmm dd"
  exit
end

db = Mongo::Connection.new.db("gs") # no error checking  :-) assume Get Satisfaction Database is there on localhost
topicsColl = db.collection("topics")

metrics_start = Time.utc(ARGV[0], ARGV[1], ARGV[2], 0, 0)
metrics_stop =  Time.utc(ARGV[3], ARGV[4], ARGV[5], 23, 59)
end_program = false

topics_created_or_updated = 0
topicsColl.find("last_active_at" => {"$gte" => metrics_start}).each do |t|
  $stderr.printf("CHECKING topic id:%d which was last active at:%s\n",t["id"], t["last_active_at"].to_s)

  time_compare = t["last_active_at"] <=> metrics_stop
  if time_compare == -1 || time_compare == 0
    $stderr.printf("IN TIME WINDOW topic id:%d\n",t["id"])
    topics_created_or_updated += 1
    next
  end

  t["reply_array"].each do |r|
    created_at = Time.parse(r["created_at"])
    $stderr.printf("CHECKING topic id:%d, reply id:%d which was last active at:%s\n",t["id"], r["id"], created_at.to_s)
    time_compare_start = created_at   <=> metrics_start
    time_compare_stop  = created_at   <=> metrics_stop
    if time_compare_start >= 0 && time_compare_stop <= 0
      $stderr.printf("REPLY id:%d IN TIME WINDOW topic id:%d\n", r["id"],t["id"])
      topics_created_or_updated += 1
      break
    end
  end
end

printf("%d Topics Created or Updated from:%d %d %d to %d %d %d\n",\
  topics_created_or_updated, ARGV[0], ARGV[1], ARGV[2],ARGV[3], ARGV[4], ARGV[5] )
