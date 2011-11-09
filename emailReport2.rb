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

def createLink(url, title, length)

return "<a title=\""+title+"\""+
     " href=\""+ url + "\">"+title[0..length-1]+"</a>"
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
                  :fields => ["at_sfn", "id", "reply_count", "reply_array", "subject", "fulltext", "tags_array"]
                ).each do |t|
  url = t["at_sfn"]
  subject = t["subject"]
  fulltext = t["fulltext"]
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
    active_topics.push({:reply_count => reply_count_for_time_period,:topic => t})
  end
end
active_topics = active_topics.sort_by{|h|h[:reply_count]}
active_html = "<ol>"
active_topics.reverse.each{|t|
  active_html = active_html + "<li>"+
    t[:reply_count].to_s+","+ createLink(t[:topic]["at_sfn"], t[:topic]["subject"],40) + " t:"
  t[:topic]["tags_array"].each do |tag|
    active_html = active_html + createLink("http://getsatisfaction.com/mozilla_messaging/tags/" + tag,
      tag, 16) + " "              
  end
  active_html = active_html + "</li>"
}
active_html = active_html + "</ol>"

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
#{active_html}
</p>
EOF
print 'content', content

Net::SMTP.enable_tls(OpenSSL::SSL::VERIFY_NONE)  
Net::SMTP.start('smtp.gmail.com', 587, 'gmail.com', from, p, :login) do |smtp| 
  smtp.send_message(content, from, to)
end


