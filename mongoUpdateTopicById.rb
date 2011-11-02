#!/usr/bin/env ruby
require 'rubygems'
require 'json'
require 'net/http'
require 'pp'
require 'time'
require 'date'
require 'mongo'
require 'getGSResponse'
require 'getGSRepliesForTopic'
require 'getGSTagsForTopic'

if ARGV.length < 1
  puts "usage: #{$0} id [-v]"
  exit
end
if ARGV[1] && ARGV[1] == "-v"
  verbose_logging = true
else
  verbose_logging = false
end

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

id = ARGV[0].to_i

topic_url = "products/mozilla_thunderbird/topics/" << "%d" % id << ".json" 
printf(STDERR, "topic_url")
begin
  topic = getResponse(topic_url)
rescue JSON::ParserError
  printf(STDERR, "Parser error in topic:%s\n", topic_url)
  exit
end

last_active_at = Time.parse(topic["last_active_at"])
last_active_at = last_active_at.utc
printf(STDERR, "TOPIC last_active_at:%s\n", last_active_at)
created_at = Time.parse(topic["created_at"])
created_at = created_at.utc
printf(STDERR, "TOPIC created_at:%s\n", last_active_at)
# JSON only transports string times so convert time to Unix time before putting it into mongo
topic.delete("last_active_at") 
topic["last_active_at"] = last_active_at
topic.delete("created_at") 
topic["created_at"] = created_at
topic["tags_array"] = [] 
topic["tag_id_array"] = []
topic["reply_id_array"] = [] 
topic["reply_array"] = []
topic["fulltext"] = "" 
topic["fulltext_with_tags"] = ""
topic["tags_str"] = "" 
topic["synthetic_status_journal"] = []
if verbose_logging
  printf(STDERR, "START*** of topic\n") 
  PP::pp(topic,$stderr)
  printf(STDERR, "\nEND*** of topic\n")
end

topic_text = topic["subject"].downcase + " " + topic["content"].downcase 
status = topic["status"]
status_update_time = last_active_at 
reply_count = topic["reply_count"] 
printf(STDERR, "reply_count:%d\n", reply_count) 
topic["reply_count"] = reply_count 
topic["fulltext"] = topic_text 
topic["fulltext_with_tags"] = topic_text
if reply_count != 0
  topic = getGSRepliesForTopic(topic, reply_count, verbose_logging)          
end # if reply_count != 0

topic = getGSTagsForTopic(topic, verbose_logging)      

existingTopic =  topicsColl.find_one("id" =>id)
if existingTopic
  if existingTopic.has_key?("synthetic_status_journal") 
    $stderr.printf("ADDING to synthetic_status_journal! current journal size:%d status:%s status_update_time:%s\n", 
      existingTopic["synthetic_status_journal"].length(), status, status_update_time)
    status_update_found = false
    existingTopic["synthetic_status_journal"].each do |journal_element|
      if (journal_element["status_update_time"] <=> status_update_time) == 0
        status_update_found = true
        break
      end
    end
    topic["synthetic_status_journal"] = existingTopic["synthetic_status_journal"]
    if !status_update_found
      $stderr.printf("status update NOT FOUND so adding it to synthetic_status_journal\n")
      topic["synthetic_status_journal"].push({ "status" => status, "status_update_time" => status_update_time })
    else
      $stderr.printf("status update FOUND so just copying OLD synthetic_status_journal\n")
    end
  else
    $stderr.printf("CREATING synthetic_status_journal! status:%s status_update_time:%s\n", status, status_update_time)
    topic["synthetic_status_journal"].push({ "status" => status, "status_update_time" => status_update_time })
  end
  $stderr.printf("UPDATING topic id:%d\n",id)
  topicsColl.update({"id" =>id},topic)
else
  $stderr.printf("INSERTING topic id:%d\n",id)
  topic["synthetic_status_journal"].push({ "status" => status, "status_update_time" => status_update_time })
  topicsColl.insert(topic)
end
