#!/usr/bin/env ruby
require 'rubygems'
require 'json'
require 'net/http'
require 'pp'
require 'time'
require 'date'
require 'mongo'
include Mongo


def getResponse(url)

  http = Net::HTTP.new("api.getsatisfaction.com",80)

  url = "/" + url 

  resp, data = http.get(url, nil)
   
  if resp.code != "200"
    puts "Error: #{resp.code} from:#{url}"
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

connection = Mongo::Connection.new.db(gs) # no error checking  :-) assume Get Satisfaction Database is there on localhost

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

    if (last_active_at <=> (metrics_start + 1)) == -1 
      printf(STDERR, "ending program\n")
      end_program = true
      break
    end
    

    printf(STDERR, "START*** of topic\n")
    PP::pp(topic,$stderr)
    printf(STDERR, "\nEND*** of topic\n")

    topic_text = topic["subject"] + " " + topic["content"]
   
    reply_count = topic["reply_count"]
  
    printf(STDERR, "reply_count:%d\n", reply_count)
    reply_page = 1
    if reply_count != 0
      begin # while reply_count > 0
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

          if (reply_created_time <=> metrics_start) == 1 &&
             (reply_created_time <=> metrics_stop) == -1
            topic_text = topic_text + " " + reply["content"]            
          else
            printf(STDERR,"Reply created by:%s at:%s topic:%s reply:%s NOT IN Time Window\n",author, reply_created_time, topic_id, reply_id)
          end
        end # replies ... do
        reply_count -= 30
        reply_page += 1
      end while reply_count > 0

     
     # creates mongodb db with topics
     # create gstopic Collection in gs db
     # index by reply last updated at (so if you new reply added or existing reply modified, create just new reply or modify existing reply using create_at since there is no last_updateed_at for topics)
     # index by fulltext
     # index by time last_active_at (convert to mongo time format which i
     # guess is js time format i.e. milliseconds since 1970)
     ## get gstopic via API and get its replies and create fulltext field
     #KLUDGE: do a complete refresh if topic was updated since the last time you updated it
      
      # instead of opencalais, create gstopic:
      # * mongoTopic = GS api topic + all api replies + api tags
      # db.things.ensureIndex({mongotopic:1});  http://www.mongodb.org/display/DOCS/Indexes
      # ** synthetic field fulltext  = subject + " "  + content + " " + reply
      # text, create_index(fulltext)
      # (http://markwatson.com/blog/2009/11/mongodb-has-good-support-for-indexing.html
      # )
      # Topic.find(:all, :conditions => {:fulltext => /^keyword e.g. water water/i}).each { |row| puts row.to_s }
      # * indexing examples http://www.slideshare.net/mongodb/indexing-with-mongodb
      # ** synthetic field fulltextWithTags = fulltext + tag.name from all
      # tags create_index(fulltextWithTags)
      # index by time to find all topics for last 6 months
      # than index by fulltext to find keywords
      # i.e. .ensureIndex({last_active_at":1})
      # http://cookbook.mongodb.org/patterns/date_range/ has example of search
      # on author and time:
      # ** db.posts.ensureIndex({author: 1, created_on: 1});
      # ** db.posts.find({author: "Mike", created_on: {$gt: start, $lt: end}});
      # http://whilefalse.net/2010/01/14/date-queries-mongodb/ :
      ## db.collection.find({$where: "this.date_field > new Date(2009, 11, 02)"}), can i index on last_updated_at filed from GS or do i need to create a new data field?,hmmm need new date field it looks like: 
      ## http://www.mongodb.org/display/DOCS/Import+Export+Tools MongoDB supports more types that JSON does, so it has a special format for representing some of these types as valid JSON. For example, JSON has no date type. Thus, to import data containing dates, you structure your JSON like:
## {"somefield" : 123456, "created_at" : {"$date" : 1285679232000}}
## http://rubylearning.com/blog/2010/12/21/being-awesome-with-the-mongodb-ruby-driver/ new_post = { :title => "RubyLearning.com, its awesome", :content => "This is a pretty sweet way to learn Ruby", :created_on => Time.now }
## i.e. use http://www.ruby-doc.org/core/classes/Time.html instead of Date and Time
# last_updated_at_mongo = Time.utc(2011,2,13,6,8,9) // using string version of ASCII time updated_at since all GS API times are UTC

      printf(STDERR, "*** opencalais topic_text:%s\n", topic_text)

      calais = CalaisClient::OpenCalaisTaggedText.new(topic_text)
      keywords = calais.get_tags
      printf(STDERR, "START*** of opencalais keywords for topic:%s\n", topic_url)
      PP::pp(keywords,$stderr)
      printf(STDERR, "\nEND*** of opencalais keywords for topic:%s\n", topic_url)
      keywords.each do |keyword_array|
        keyword_array.each do |keyword|
          if !keyword.respond_to?(:chomp, include_private = false)
            keyword.each do |k|
              printf(STDERR, "*** opencalais individual keyword:%s\n", k)
              tag_is_stop_word = false
              STOP_WORDS.each do|stop_word|
                if stop_word == k
                  tag_is_stop_word = true
                  break
                end
              end
              if !tag_is_stop_word && k.length != 0 && !k.include?("http")
                printf("keyword:%s,url:%s\n", k, topic_url)
              end
            end          
          else 
            printf(STDERR, "*** opencalais individual keyword:%s\n", keyword.to_s)
            tag_is_stop_word = false
            STOP_WORDS.each do|stop_word|
              if stop_word == keyword.to_s
                tag_is_stop_word = true
                break
              end
            end
          end
          if !tag_is_stop_word && keyword.to_s.length != 0 && !keyword.to_s.include?("http")
            printf(STDERR, "*** opencalas NOT adding individual keyword since it's a string\n")
            # printf("keyword:%s,url:%s\n", keyword.to_s, topic_url)
          end
        end
      end
    end
  end 
  if end_program
    break
  end
end




