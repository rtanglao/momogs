#!/usr/bin/env ruby
require 'rubygems'
require 'json'
require 'net/http'
require 'pp'
require 'date'
require 'time'
 
def getResponse(url)
 
  http = Net::HTTP.new("api.getsatisfaction.com",80)
 
  url = "/" + url
 
  resp, data = http.get(url, nil)
   
  if resp.code != "200"
    puts "Error: #{resp.code} from:#{url}"
    raise JSON::ParserError
    return ""
  end
 
  result = JSON.parse(data)
  return result
end
 
if ARGV.length < 6
  puts "usage: #{$0} yyyy mm dd yyyy mmm dd"
  exit
end
 
metrics_start = Time.utc(ARGV[0], ARGV[1], ARGV[2], 0, 0)
metrics_start -= 1
metrics_stop = Time.utc(ARGV[3], ARGV[4], ARGV[5], 23, 59)
metrics_stop += 1
topic_page = 0
end_program = false
contributors = {}
 
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
    reply_count = topic["reply_count"]
  
    printf(STDERR, "reply_count:%d\n", reply_count)
    reply_page = 1
    if reply_count != 0
      begin # while reply_count > 0
        get_reply_url = "topics/" << topic["slug"] << "/replies.json?sort=recently_created&page=" << "%d" % reply_page << "&limit=30"
 
        PP::pp(get_reply_url, $stderr)
        skip = false
        begin
          replies = getResponse(get_reply_url)
        rescue JSON::ParserError
          printf(STDERR, "Parser error in reply:%s\n", get_reply_url)
          skip = true
        end
        if skip
          skip = false
          reply_count -= 30
          reply_page += 1         
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
          star_promoted = reply["star_promoted"]
          company_promoted = reply["company_promoted"]
          specific_reply_url = reply["url"]
          printf(STDERR, "RRR: reply created time:%s\n", reply_created_time)
 
          if (reply_created_time <=> metrics_start) == 1 &&
              (reply_created_time <=> metrics_stop) == -1
            puts "Reply created by:#{author} at:#{reply_created_time} topic:#{topic_id} reply:#{reply_id} star_promoted:#{star_promoted} company_promoted:#{company_promoted} IN Time Window"
            if star_promoted || company_promoted
              printf(STDERR, "%s has a company promoted or star promoted reply at reply url:%s content:%s\n", author, specific_reply_url, reply["content"])
              if contributors.has_key?(author)
                contributors[author] += 1
              else
                contributors[author] = 1
              end
            end
          else
            printf(STDERR,"Reply created by:%s at:%s topic:%s reply:%s NOT IN Time Window\n",author, reply_created_time, topic_id, reply_id)
          end
        end # replies ... do
        reply_count -= 30
        reply_page += 1 
      end while reply_count > 0
    end # reply_count != 0
  end # topics["data"].each do|topic|
  if end_program
    break
  end
end
 
sorted_array=[]
index = 0
contributors.sort{|author,numReplies| author[1]<=>numReplies[1]}.each { |elem|
  puts "#{elem[1]}, #{elem[0]}"
  sorted_array[index]={}
  sorted_array[index]["numReplies"]=elem[1]
  sorted_array[index]["author"]=elem[0]
  index += 1
}
executable_name = $0.gsub(".rb","") 
printf(STDERR, "CSV filename:%s.%s%s%s.%s%s%s.csv",executable_name,ARGV[0],ARGV[1],ARGV[2],ARGV[3],ARGV[4],ARGV[5])
 
csv_file = File.new(executable_name+"."+ARGV[0]+ARGV[1]+ARGV[2]+"."+ARGV[3]+ARGV[4]+ARGV[5] + ".csv", "w")
 
sorted_array.reverse.each{|row|
  csv_file.puts "#{row['numReplies']},#{row['author']}"
}
 
csv_file.close
