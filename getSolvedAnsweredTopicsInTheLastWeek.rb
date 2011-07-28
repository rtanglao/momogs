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
metrics_start = metrics_stop - (1 * 7 * 60 * 60 * 24) # 1 week ago

end_program = false
# topics = db.topics.find({synthetic_status_journal : { 
# {at_sfn:-1,_id:0,synthetic_status_journal:-1})

topicsColl.find({"last_active_at" => {"$gte" => metrics_start, "$lt" => metrics_stop},
                  "status" => "complete"},
                  :fields => ["last_active_at", "at_sfn", "id", "subject", "synthetic_status_journal"]).each do |t|
  $stderr.printf("***START of topic\n")
  PP::pp(t,$stderr)
  $stderr.printf("***END of topic\n")
  $stderr.printf("FOUND topic url:%s id:%d which was last_active_at at:%s\n",t["at_sfn"],t["id"], t["last_active_at"].to_s)
  printf("%s,%s\n",t["subject"],t["at_sfn"])

end # topic iterator
