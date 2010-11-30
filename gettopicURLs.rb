#!/usr/bin/env ruby
require 'rubygems'
require 'json'
require 'net/http'
require 'pp'
require 'time'
require 'date' 

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
executable_name = $0.gsub(".rb","") 
printf(STDERR, "CSV filename:%s.%s%s%s.%s%s%s.csv",executable_name,ARGV[0],ARGV[1],ARGV[2],ARGV[3],ARGV[4],ARGV[5])

csv_file = File.new(executable_name+"."+ARGV[0]+ARGV[1]+ARGV[2]+"."+ARGV[3]+ARGV[4]+ARGV[5] + ".csv", "w")


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

    title = topic["subject"]
    url = topic["at_sfn"]
    #csv_file.puts "#{url},#{created_at}"
    csv_file.puts "#{url}"
 
  end 
  if end_program
    break
  end
end

csv_file.close


