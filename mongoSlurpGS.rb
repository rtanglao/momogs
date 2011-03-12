#!/usr/bin/env ruby
require 'rubygems'
require 'json'
require 'net/http'
require 'pp'
require 'time'
require 'date'
require 'mongo'

def getResponse(url)

  http = Net::HTTP.new("api.getsatisfaction.com",80)

  url = "/" + url 

  resp, data = http.get(url, nil)
   
  if resp.code != "200"
    printf(STDERR, "getResponse Parser Error: #%d from:%s\n", resp.code, url)
    raise JSON::ParserError    # this is a kludge, should raise a proper exception!!!!!
    return ""
  end

  result = JSON.parse(data)
  return result
end

if ARGV.length < 6
  puts "usage: #{$0} yyyy mm dd yyyy mmm dd"
  exit
end

db = Mongo::Connection.new.db("gs") # no error checking  :-) assume Get Satisfaction Database is there on localhost
topicsColl = db.collection("topics")

metrics_start = Time.utc(ARGV[0], ARGV[1], ARGV[2], 0, 0)
metrics_start -= 1
metrics_stop =  Time.utc(ARGV[3], ARGV[4], ARGV[5], 23, 59)
metrics_stop += 1
roland_replies = 0
non_roland_replies = 0
topic_page = 0
end_program = false
repliesByUser={}

while true
  topic_page += 1
  skip = false
  topic_url = "products/mozilla_thunderbird/topics.json?sort=recently_active&page=" << "%d" % topic_page << "&limit=30"
  printf(STDERR, "topic_url")
  begin
    topics = getResponse(topic_url)
  rescue JSON::ParserError
    printf(STDERR, "Parser error in topic:%s\n", topic_url)

    skip = true
  end
  if skip
    skip = false
    next
  end
  topics["data"].each do|topic|
    topic_url = "http://getsatisfaction.com/mozilla_messaging/topics/" + topic["slug"]
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

    if (last_active_at <=> (metrics_start + 1)) == -1 
      printf(STDERR, "ending program\n")
      end_program = true
      break
    end
    
    topic["tags_array"] = []
    topic["tag_id_array"] = []
    topic["reply_id_array"] = []
    topic["fulltext"] = ""
    topic["fulltext_with_tags"] = ""

    printf(STDERR, "START*** of topic\n")
    PP::pp(topic,$stderr)
    printf(STDERR, "\nEND*** of topic\n")

    topic_text = topic["subject"].downcase + " " + topic["content"].downcase
   
    reply_count = topic["reply_count"]
  
    printf(STDERR, "reply_count:%d\n", reply_count)
    topic["fulltext"] = topic_text
    reply_page = 1
    if reply_count != 0
      begin # while reply_count > 0
        topic["reply_count"] = reply_count
        get_reply_url = "topics/" + topic["slug"] + "/replies.json?sort=recently_created&page=" << "%d" % reply_page << "&limit=30"

        PP::pp(get_reply_url, $stderr)
        skip = false
        begin 
          replies = getResponse(get_reply_url)
        rescue JSON::ParserError
          printf(STDERR, "Parser error in reply:%s\n", get_reply_url)
          reply_count -= 30
          reply_page += 1
          skip = true
        end
        if skip
          skip = false
          next
        end

        replies["data"].each do|reply|
    
          printf(STDERR, "START*** of reply\n")
          PP::pp(reply, $stderr)
          printf(STDERR, "\nEND*** of reply\n")

          author = reply["author"]["canonical_name"]
          reply_created_time = Time.parse(reply["created_at"])
          reply_created_time = reply_created_time.utc
          topic_id = reply["topic_id"]
          reply_id = reply["id"]

          printf(STDERR, "RRR: reply created time:%s\n", reply_created_time)
          # always get all replies
          topic["fulltext"] = topic["fulltext"] + " " +  reply["content"].downcase
          topic["reply_id_array"].push(reply["id"])
        end # replies ... do
        reply_count -= 30
        reply_page += 1
        tags_page = 1
        tag_count = 0
        first_tag_page = true

        begin  # while tag_count > 0         
          get_tags_url = "topics/" + topic["slug"] + "/tags.json?page=" << "%d" % tags_page << "&limit=30"

          PP::pp(get_tags_url, $stderr)
          skip = false
          begin 
            tags = getResponse(get_tags_url)
          rescue JSON::ParserError
            printf(STDERR, "Parser error in HTTP GET of tag url:%s\n", get_tags_url)
            tags_count -= 30
            tags_page += 1
            skip = true
          end
          if skip
            skip = false
            next
          end

          if first_tag_page
            tag_count = tags["total"]
            topic["tag_count"] = tag_count
            first_tag_page = false
          end
          tags["data"].each do|tag|    
            printf(STDERR, "START*** of tag\n")
            PP::pp(tag, $stderr)
            printf(STDERR, "\nEND*** of tag\n")
            tag_name = tag["name"].downcase
            topic["tags_array"].push(tag_name)
            topic["tag_id_array"].push(tag["id"])
            topic["tags_str"] = tag_name + "~"
            topic["fulltext_with_tags"] = topic["fulltext"] + " " + tag_name
          end # tags ... do
          tag_count -= 30
          tags_page += 1                   
        end while tag_count > 0
      end while reply_count > 0

      topicsColl.insert(topic)
    
    end
  end  
  if end_program
    break
  end
end
# index on "id", which is GS unique id to allow for future updates
topicsColl.create_index([['created_at', Mongo::DESCENDING], ['last_active_at',Mongo::DESCENDING], ['id',Mongo::DESCENDING],['tags_str',Mongo::DESCENDING]])




