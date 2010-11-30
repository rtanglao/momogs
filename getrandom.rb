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
    puts "Error: #{resp.code} from:#{url}"
    raise JSON::ParserError   # this is a kludge fix me!  
    return ""
  end

  result = JSON.parse(data)
  return result
end

if ARGV.length < 7
  puts "usage: #{$0} yyyy mm dd yyyy mmm dd #numtopics"
  exit
end

metrics_start = Time.utc(ARGV[0], ARGV[1], ARGV[2], 0, 0)
metrics_start -= 1
metrics_stop =  Time.utc(ARGV[3], ARGV[4], ARGV[5], 23, 59)
numRandomTopicsToPick = Integer(ARGV[6])
printf(STDERR, "numRandomTopicsToPick:%d", numRandomTopicsToPick)

metrics_stop += 1

topic_page = 0
end_program = false
topics_array = []

while true
  topic_page += 1
  skip = false
  topic_url = "products/mozilla_thunderbird/topics.json?sort=recently_created&page=" << "%d" % topic_page << "&limit=30"
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
    created_at = Time.parse(topic["created_at"])
    created_at = created_at.utc
    printf(STDERR, "TOPIC created_at:%s\n", created_at)

    if (created_at <=> (metrics_start + 1)) == -1 
      printf(STDERR, "ending program\n")
      end_program = true
      break
    end

    printf(STDERR, "START*** of topic\n")
    PP::pp(topic,$stderr)
    printf(STDERR, "\nEND*** of topic\n")

    canonical_topic_url = "http://getsatisfaction.com/mozilla_messaging/topics/" + topic["slug"]
    topics_array << canonical_topic_url   
  end 
  if end_program
    break
  end
end

random_topics=[]
for i in 1..numRandomTopicsToPick do
  while true do
    index = rand(topics_array.length)
    if topics_array[index] != nil
      random_topics[i] = topics_array[index]
      topics_array[index] = nil
      break
    end
  end
end

executable_name = $0.gsub(".rb","") 
printf(STDERR, "CSV filename:%s.%s%s%s.%s%s%s.csv",executable_name,ARGV[0],ARGV[1],ARGV[2],ARGV[3],ARGV[4],ARGV[5])

csv_file = File.new(executable_name+"."+ARGV[0]+ARGV[1]+ARGV[2]+"."+ARGV[3]+ARGV[4]+ARGV[5] + ".csv", "w")

random_topics.each{|topic_url|
  csv_file.puts "#{topic_url}"
}

csv_file.close


