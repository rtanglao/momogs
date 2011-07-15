#!/usr/bin/env ruby
require 'rubygems'
require 'json'
require 'pp'
require 'date'
require 'time'
require 'mongo'

providers = []
mailProviderMentionsByHour = {}
regexes = []

metrics_start = Time.utc(ARGV[0], ARGV[1], ARGV[2], 0, 0)
metrics_stop = Time.utc(ARGV[0], ARGV[1], ARGV[2], 23, 59)

f = File.open("mailProviderRegex.txt") or die "Unable to open mailProviderRegex.txt..."
mailProviderRegexStr = [] 
f.each_line {|line| mailProviderRegexStr.push line.gsub(/\n/, "")}
regexes = mailProviderRegexStr.collect {|re_str|%r|#{re_str}|}
providers =  mailProviderRegexStr.collect {|re_str|re_str.gsub(/\W/,"")}

providers.each do |p|
  for h in 0..23 do
    yyyymmddhh_provider_str = metrics_start.year.to_s + sprintf("%0.2d",metrics_start.month.to_i) + 
      sprintf("%0.2d",metrics_start.day.to_i) + sprintf("%0.2d",h) + p
    mailProviderMentionsByHour[yyyymmddhh_provider_str] = 0
  end
end

def check_for_providers(text,url,updated_time,regexes,providers,mailProviderMentionsByHour)
  regexes.each_with_index do |re,i|
    if re.match text 
      yyyymmddhh_provider_str = updated_time.year.to_s + sprintf("%0.2d",updated_time.month) + 
        sprintf("%0.2d",updated_time.day.to_i) + sprintf("%0.2d",updated_time.hour) + providers[i]
      $stderr.printf("match DETECTED in text:%s for topic:%s for provider:%s\n",text,url,providers[i])
      mailProviderMentionsByHour[yyyymmddhh_provider_str] += 1
    end
  end
end

if ARGV.length < 3
  puts "usage: #{$0} yyyy mm dd"
  exit
end

db = Mongo::Connection.new.db("gs") # no error checking  :-) assume Get Satisfaction Database is there on localhost
topicsColl = db.collection("topics")

topicsColl.find({"last_active_at" => {"$gte" => metrics_start, "$lte" => metrics_stop},
                 "reply_array" => { "$elemMatch"  => { "created_at" =>  {"$gte" => metrics_start, "$lte" => metrics_stop }}}},
  :fields => ["last_active_at", "reply_array", "tags_str", "content", "subject", "most_recent_activity", "at_sfn"]
                ).each do |t|
  url = t["at_sfn"]
  if t["most_recent_activity"] == "create"
    last_active_at = t["last_active_at"]
    topic_text = t["subject"].downcase + " " + t["content"].downcase + " " +  t["tags_str"]
    check_for_providers(topic_text,url,last_active_at,regexes,providers,mailProviderMentionsByHour)
    next # skip replies since last activity was creation of topic
  end
         
  $stderr.printf("NO match DETECTED in: subject, content or tags for topic:%s; checking REPLIES\n",url)

  t["reply_array"].each do |r|
    created_at = r["created_at"]
    if ((created_at <=> metrics_start) >= 0) && ((created_at <=> metrics_stop) <= 0)
      $stderr.printf("reply:%d IN time period\n", r["id"])
      check_for_providers(r["content"].downcase,url,created_at,regexes,providers,mailProviderMentionsByHour)
    else
      $stderr.printf("reply:%d NOT IN time period\n", r["id"])
    end    
  end
end
 
executable_name = $0.gsub(".rb","") 
printf(STDERR, "CSV filename:%s.%s%s%s.csv",executable_name,ARGV[0],ARGV[1],ARGV[2])
 
csv_file = File.new(executable_name+"."+ARGV[0]+ARGV[1]+ARGV[2] + ".csv", "w")
csv_file.puts("Hour,Provider,NumMentions")

providers.each do |p|
  for h in 0..23 do
    yyyymmddhh_provider_str = metrics_start.year.to_s + sprintf("%0.2d",metrics_start.month) + 
        sprintf("%0.2d",metrics_start.day.to_i) + sprintf("%0.2d",h) + p
    csv_file.printf("%s,%s,%d\n", metrics_start.year.to_s + sprintf("%0.2d",metrics_start.month.to_i) + 
        sprintf("%0.2d",metrics_start.day.to_i) + sprintf("%0.2d",h),
      p, mailProviderMentionsByHour[yyyymmddhh_provider_str])
  end
end
 
csv_file.close
