#!/usr/bin/env ruby
require 'rubygems'
require 'json'
require 'pp'
require 'time'
require 'date'
require 'mongo'

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

if ARGV.length < 1
  puts "usage: #{$0} [number_of_days]"
  exit
end

metrics_stop =  Time.now
number_of_days_to_look_for_answered_topics = ARGV[0].to_i

metrics_start = metrics_stop - (number_of_days_to_look_for_answered_topics * 60 * 60 * 24) 

end_program = false

topicsColl.find({"last_active_at" => {"$gte" => metrics_start, "$lt" => metrics_stop},
                  "status" => "complete"},
                  :fields => ["last_active_at", "at_sfn", "id", "subject", "synthetic_status_journal"]).each do |t|
  $stderr.printf("***START of topic\n")
  PP::pp(t,$stderr)
  $stderr.printf("***END of topic\n")
  $stderr.printf("FOUND topic url:%s id:%d which was last_active_at at:%s\n",t["at_sfn"],t["id"], t["last_active_at"].to_s)
  printf("%s,%s\n",t["subject"].gsub(","," - ")[0..79],t["at_sfn"])

end # topic iterator
