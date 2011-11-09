#!/usr/bin/env ruby
require 'rubygems'
require 'json'
require 'net/http'
require 'pp'
require 'time'
require 'tlsmail'
require 'date'
require 'parseconfig'
require 'mongo'

providers = []
regexes = []

def check_for_providers(text, regexes, providers)
  provider_mentions = []
  regexes.each_with_index do |re,i|
    if re.match text 
      provider_mentions.push(providers[i])
    end
  end
  return provider_mentions
end

def createLink(url, title, length)
  return "<a title=\""+title+"\""+
     " href=\""+ url + "\">"+title[0..length-1]+"</a>"
end

f = File.open("mailProviderRegex.txt") or die "Unable to open mailProviderRegex.txt..."
mailProviderRegexStr = [] 
f.each_line {|line| mailProviderRegexStr.push line.gsub(/\n/, "")}
regexes = mailProviderRegexStr.collect {|re_str|%r|#{re_str}|}
providers =  mailProviderRegexStr.collect {|re_str|re_str.gsub(/\W/,"")}


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


metrics_start = Time.utc(ARGV[0], ARGV[1], ARGV[2], 0, 0)
metrics_stop =  Time.utc(ARGV[3], ARGV[4], ARGV[5], 23, 59)

executable_name = $0.gsub(".rb","")

start_date = ARGV[0] + ARGV[1] + ARGV[2]

active_topics = []
# find active topics that have replies in the time period and 
# then record:
#   number of replies, url, subject, top 5 tags, top 5 mail providers, top 5 isps 
topicsColl.find({"reply_array" => { "$elemMatch"  => 
                    { "created_at" =>  {"$gte" => metrics_start, "$lte" => metrics_stop }}}},
                  :fields => ["at_sfn", "id", "reply_count", "reply_array", "subject", "fulltext_with_tags", "tags_array"]
                ).each do |t|
  url = t["at_sfn"]
  subject = t["subject"]
  fulltext_with_tags = t["fulltext_with_tags"]
  tags_array = t["tags_array"]
  reply_count_for_time_period = 0
  t["reply_array"].each do |r|
    created_at = r["created_at"]
    if ((created_at <=> metrics_start) >= 0) && ((created_at <=> metrics_stop) <= 0)
      reply_count_for_time_period += 1
      $stderr.printf("reply:%d IN time period\n", r["id"])
    else
      $stderr.printf("reply:%d NOT IN time period\n", r["id"])
    end    
  end
  if reply_count_for_time_period > 0
    provider_mentions = check_for_providers(fulltext_with_tags, regexes, providers)
    active_topics.push({:provider_mentions => provider_mentions, :reply_count => reply_count_for_time_period,:topic => t})
  end
end
active_topics = active_topics.sort_by{|h|h[:reply_count]}
active_html = ""
active_topics.reverse.each do |t|
  $stderr.printf("active_html:%s\n", active_html)
  active_html = active_html + "<tr><td>"+
    t[:reply_count].to_s+"</td><td>"+ createLink(t[:topic]["at_sfn"], t[:topic]["subject"],40) + "</td><td>"
  t[:topic]["tags_array"].each do |tag|
    active_html = active_html + createLink("http://getsatisfaction.com/mozilla_messaging/tags/" + tag,
      tag, 16) + " "              
  end
  active_html = active_html + "</td><td>"
  t[:provider_mentions].each{|p| active_html = active_html + p[0..15] + " " }
  active_html = active_html + "</td></tr>"
end

email_config = ParseConfig.new('email.conf').params
from = email_config['from_address']
to = email_config['to_address']
p = email_config['p']
subject = "Thunderbird Support Report FROM: %d.%d.%d TO: %d.%d.%d generated:%s" % [ARGV[0],ARGV[1],ARGV[2],ARGV[3], ARGV[4], ARGV[5], Time.now]
content = <<EOF
From: #{from}
To: #{to}
MIME-Version: 1.0
Content-type: text/html
subject: #{subject}
Date: #{Time.now.rfc2822}

<h3>Get Satisfaction Top 5 Active:</h3>
<p>
<table border="1">
<tr>
<th>replies</th>
<th>url</th>
<th>t</th>
<th>p</th>
</tr>
#{active_html}
</table>
</p>
EOF
print 'content', content

Net::SMTP.enable_tls(OpenSSL::SSL::VERIFY_NONE)  
Net::SMTP.start('smtp.gmail.com', 587, 'gmail.com', from, p, :login) do |smtp| 
  smtp.send_message(content, from, to)
end


