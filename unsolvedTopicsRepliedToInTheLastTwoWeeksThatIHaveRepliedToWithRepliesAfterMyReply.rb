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
gs_contributor = "rtanglao"
# query in mongo shell:
# db.topics.find({"created_at": {$gte: start23, $lt: end23},"status":{$nin:  
# ["complete","rejected"]},reply_array: { $elemMatch : { "author.canonical_name" : 
# "rtanglao"}}},{"at_sfn": -1}) 
topicsColl.find({"created_at" => {"$gte" => metrics_start, "$lt" => metrics_stop},
                  "status" => { "$nin" => ["complete","rejected"]},
                  "reply_array" => { "$elemMatch"  => { "author.canonical_name" => gs_contributor}}}).each do |t|
  $stderr.printf("CHECKING topic url:%s id:%d which was created at:%s\n",t["at_sfn"],t["id"], t["created_at"].to_s)
  # search this topics replies to see if there are any replies AFTER gs_contributor_last_reply, if so print out the url
  last_gs_contributor_reply_time = Time.utc(2009,1,1) # since all topics in the database were created after july 20, 2009
  newest_reply_time = last_gs_contributor_reply_time
  last_reply_is_gs_contributor = false
  t["reply_array"].each do |reply|
    reply_author = reply["author"]["canonical_name"]
    reply_time = Time.parse(reply["created_at"])
    reply_time = reply_time.utc
    $stderr.printf("CHECKING reply url:%s id:%d which was created at:%s BY:%s\n",reply["url"],reply["id"], reply_time.to_s,
      reply_author)
    if (reply_time <=> newest_reply_time) == 1
      $stderr.printf("Reply time is greater than newest_reply_time\n")
      newest_reply_time = reply_time
      if reply_author == gs_contributor 
        if (reply_time <=> last_gs_contributor_reply_time) == 1
          last_gs_contributor_reply_time = reply_time
          last_reply_is_gs_contributor = true
        end
        next
      end
      if (reply_time <=> last_gs_contributor_reply_time) == 1
          last_gs_contributor_reply_time = reply_time
          last_reply_is_gs_contributor = false
      end      
    end
  end
  if !last_reply_is_gs_contributor
    printf("Please reply to: %s\n", t["at_sfn"])
  else
    $stderr.printf("No need to reply to: %s\n", t["at_sfn"])
  end
end
