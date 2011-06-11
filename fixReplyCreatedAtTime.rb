#!/usr/bin/env ruby
require 'rubygems'
require 'json'
require 'pp'
require 'time'
require 'date'
require 'mongo'

db = Mongo::Connection.new.db("gs") # no error checking  :-) assume Get Satisfaction Database is there on localhost
topicsColl = db.collection("topics")

topicsColl.find().each do |t|
  $stderr.printf("CHECKING topic url:%s id:%d which was created at:%s\n",t["at_sfn"],t["id"], t["created_at"].to_s)
  topic_reply_time_updated = false
  t["reply_array"].each do |reply|
    if reply["created_at"].kind_of? String
      $stderr.printf("String reply created_at:%s\n", reply["created_at"])
      reply["created_at"] = Time.parse(reply["created_at"]).utc
      $stderr.printf("ISODate reply created_at:%s\n", reply["created_at"].to_s)
      topic_reply_time_updated = true
    end
  end
  if topic_reply_time_updated
    $stderr.printf("UPDATING reply_array for topic id:%d\n",t["id"])
    topicsColl.update({"id" =>t["id"]},t,{"$set" => {"reply_array" => t["reply_array"]}})
  else
    $stderr.printf("NOT UPDATING reply_array for topic id:%d\n",t["id"])
  end
end
