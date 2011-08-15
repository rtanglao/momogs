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

updated_topics = []
topicsColl.find({"reply_array" => { "$elemMatch"  => 
                    { "created_at" =>  {"$gte" => metrics_start, "$lte" => metrics_stop }}}},
                  :fields => ["at_sfn", "id", "reply_count", "reply_array"]
                ).each do |t|
  $stderr.printf("topic:%d, reply_count:%d\n", t["id"], t["reply_count"])
  url = t["at_sfn"]
  reply_count_for_time_period = 0
  t["reply_array"].each do |r|
    created_at = r["created_at"]
    if ((created_at <=> metrics_start) >= 0) && ((created_at <=> metrics_stop) <= 0)
      reply_count_for_time_period += 1
      $stderr.printf("reply:%d IN time period\n", r["id"])
    else
      $stderr.printf("reply:%d NOT IN time period\n", r["id"])
    end    
  end
  if reply_count_for_time_period > 0
    updated_topics.push({:reply_count => reply_count_for_time_period,:url => url})
  end
end
 
executable_name = $0.gsub(".rb","") 
printf(STDERR, "CSV filename:%s.%s%s%s.%s%s%s.csv",executable_name,ARGV[0],ARGV[1],ARGV[2],ARGV[3],ARGV[4],ARGV[5])
 
csv_file = File.new(executable_name+"."+ARGV[0]+ARGV[1]+ARGV[2]+"."+ARGV[3]+ARGV[4]+ARGV[5] + ".csv", "w")

updated_topics = updated_topics.sort_by{|h|h[:reply_count]}
updated_topics.reverse.each{|row|
  csv_file.puts "#{row[:reply_count]},#{row[:url]}"
}
 
csv_file.close
