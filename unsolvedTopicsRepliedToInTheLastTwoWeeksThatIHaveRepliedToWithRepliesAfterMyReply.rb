#!/usr/bin/env ruby
require 'rubygems'
require 'json'
require 'pp'
require 'time'
require 'date'
require 'mongo'

db = Mongo::Connection.new.db("gs") # no error checking  :-) assume Get Satisfaction Database is there on localhost
topicsColl = db.collection("topics")

metrics_stop =  Time.now
metrics_start = metrics_stop - (2 * 7 * 60 * 60 * 24) # 2 weeks ago

end_program = false

topics_created_or_updated = 0
# query in mongo shell:
# db.topics.find({"created_at": {$gte: start23, $lt: end23},"status":{$nin:  
# ["complete","rejected"]},reply_array: { $elemMatch : { "author.canonical_name" : 
# "rtanglao"}}},{"at_sfn": -1}) 
topicsColl.find({"created_at" => {"$gte" => metrics_start, "$lt" => metrics_stop},
                  "status" => { "$nin" => ["complete","rejected"]},
                  "reply_array" => { "$elemMatch"  => { "author.canonical_name" => "rtanglao"}}}).each do |t|
  $stderr.printf("CHECKING topic url:%s id:%d which was last active at:%s\n",t["at_sfn"],t["id"], t["last_active_at"].to_s)

end

#   time_compare = t["last_active_at"] <=> metrics_stop
#   if time_compare == -1 || time_compare == 0
#     $stderr.printf("IN TIME WINDOW topic id:%d\n",t["id"])
#     topics_created_or_updated += 1
#     next
#   end

#   t["reply_array"].each do |r|
#     created_at = Time.parse(r["created_at"])
#     $stderr.printf("CHECKING topic id:%d, reply id:%d which was last active at:%s\n",t["id"], r["id"], created_at.to_s)
#     time_compare_start = created_at   <=> metrics_start
#     time_compare_stop  = created_at   <=> metrics_stop
#     if time_compare_start >= 0 && time_compare_stop <= 0
#       $stderr.printf("REPLY id:%d IN TIME WINDOW topic id:%d\n", r["id"],t["id"])
#       topics_created_or_updated += 1
#       break
#     end
#   end
# end

# printf("%d Topics Created or Updated from:%d %d %d to %d %d %d\n",\
#   topics_created_or_updated, ARGV[0], ARGV[1], ARGV[2],ARGV[3], ARGV[4], ARGV[5] )
