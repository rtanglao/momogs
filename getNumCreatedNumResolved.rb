#!/usr/bin/env ruby
require 'json'
require 'net/http'
require 'pp'
require 'Time'

def getResponse(url)

  http = Net::HTTP.new("api.getsatisfaction.com",80)

  url = "/" + url 

  resp, data = http.get(url, nil)
   
  if resp.code != "200"
    puts "Error: #{resp.code}"
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
metrics_stop =  Time.utc(ARGV[3], ARGV[4], ARGV[5], 23, 59)
metrics_stop += 1
topic_page = 0

end_program = false
new_topics_per_day={}
resolved_topics_per_day={}

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
    created_at = Time.parse(topic["created_at"])
    created_at = created_at.utc

    status = topic["status"]
    printf(STDERR, "TOPIC created_at:%s last_active_at:%s status:%s\n", created_at, last_active_at, status)

    if (last_active_at <=> (metrics_start + 1)) == -1 
      printf(STDERR, "topic updated before start date at:%s so ending program\n", last_active_at)
      end_program = true
      break
    end

    if (created_at <=> metrics_stop) == 1 
      printf(STDERR, "topic created after end at:%s, so breaking\n", created_at)
      break
    end
        
    if (created_at <=> metrics_start ) == 1
      # created in correct window, i.e. after metrics_start before metrics_stop
      created_at_index = created_at.strftime("%Y%m%d")
      if new_topics_per_day.has_key?(created_at_index)
        new_topics_per_day[created_at_index] += 1
      else
        new_topics_per_day[created_at_index] = 1
      end
    end

    if (status == "complete") && (last_active_at <=> metrics_stop) == -1
      # resolved aka "complete"  in correct window i.e.after metrics_start before metrics_stop
      printf(STDERR, "START*** of RESOLVED topic\n")
      PP::pp(topic,$stderr)
      printf(STDERR, "\nEND*** of RESOLVED topic\n")
      last_active_at_index = last_active_at.strftime("%Y%m%d")
      if resolved_topics_per_day.has_key?(last_active_at_index)
        resolved_topics_per_day[last_active_at_index] += 1
      else
        resolved_topics_per_day[last_active_at_index] = 1
      end
    end

  end 
  if end_program
    break
  end

end
print("New topics per day****\n")
new_topics_per_day = new_topics_per_day.sort
new_topics_per_day.each {|date,num_new_topics_per_date|printf("date:%s #new support topics:%d\n",date, num_new_topics_per_date)}
printf("Topics resolved per day****\n")
resolved_topics_per_day = resolved_topics_per_day.sort
resolved_topics_per_day.each {|date,num_resolved_topics_per_date|printf("date:%s #resolved support topics:%d\n",date, num_resolved_topics_per_date)}
