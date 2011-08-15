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

metrics_stop =  Time.now
metrics_start = metrics_stop - (2 * 7 * 60 * 60 * 24) # 2 weeks ago

end_program = false

topics_created_or_updated = 0
gs_contributor = "rtanglao"
# query in mongo shell:
# db.topics.find({"last_active_at": {$gte: start23, $lt: end23},"status":{$nin:  
# ["complete","rejected"]},reply_array: { $elemMatch : { "author.canonical_name" : 
# "rtanglao"}}},{"at_sfn": -1}) 
topicsColl.find({"last_active_at" => {"$gte" => metrics_start, "$lt" => metrics_stop},
                  "status" => { "$nin" => ["complete","rejected"]},
                  "reply_array" => { "$elemMatch"  => { "author.canonical_name" => gs_contributor}}},
                  :fields => ["at_sfn", "id", "created_at", "last_active_at", "fulltext", "reply_array", "tags_str"]).each do |t|
  # if the topic is tagged "rtcloseme" then skip it to get around GS's lack of a "close topic" feature
  # if the topic is tagged "rtnothingtoadd" then skip it as i have nothing further to add to a topic (used for RFE topics)
  if t["tags_str"].include?("rtcloseme") ||  t["tags_str"].include?("rtnothingtoadd")
    $stderr.printf("topic:%s has tag rtcloseme or rtnothingtoadd, SKIPPING\n",t["at_sfn"])
    next
  end
  $stderr.printf("***START of topic\n")
  PP::pp(t,$stderr)
  $stderr.printf("***END of topic\n")
  $stderr.printf("CHECKING topic url:%s id:%d which was created at:%s\n",t["at_sfn"],t["id"], t["created_at"].to_s)
  # search this topics replies to see if the last reply is by gs_contributor, if it's not then gs_contributor should reply
  newest_reply_time = Time.utc(2009,1,1) # since all topics in the database were created after july 20, 2009
  last_reply_is_gs_contributor = false
  t["reply_array"].each do |reply|
    reply_time = reply["created_at"]
    reply_author = reply["author"]["canonical_name"]
    $stderr.printf("CHECKING reply url:%s id:%d which was created at:%s BY:%s\n",reply["url"],reply["id"], reply_time.to_s,
      reply_author)
    if (reply_time <=> newest_reply_time) == 1
      $stderr.printf("Reply time is greater than newest_reply_time\n")
      newest_reply_time = reply_time
      if reply_author == gs_contributor 
        last_reply_is_gs_contributor = true
      else 
        last_reply_is_gs_contributor = false
      end 
    end # reply is after newest_reply_time
  end # reply iterator
  if !last_reply_is_gs_contributor
    printf("Please reply to: %s\n", t["at_sfn"])
  else
    $stderr.printf("No need to reply to: %s\n", t["at_sfn"])
  end
end # topic iterator
