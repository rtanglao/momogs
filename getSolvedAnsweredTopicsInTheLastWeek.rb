#!/usr/bin/env ruby
require 'rubygems'
require 'json'
require 'pp'
require 'time'
require 'date'
require 'mongo'
require 'tlsmail'
require 'date'
require 'parseconfig'

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

if ARGV.length < 4
  puts "usage: #{$0} yyyy mm dd [number_of_days]"
  exit
end

metrics_stop = Time.utc(ARGV[0], ARGV[1], ARGV[2], 0, 0)
number_of_days_to_look_for_answered_topics = ARGV[3].to_i
metrics_start = metrics_stop - (number_of_days_to_look_for_answered_topics * 60 * 60 * 24) 

personPlusSolvedURLs = "<ol>"

topicsColl.find({"last_active_at" => {"$gte" => metrics_start, "$lt" => metrics_stop},
                  "status" => "complete"},
                  :fields => ["last_active_at", "at_sfn", "id", "subject", "synthetic_status_journal","author"]).each do |t|
  $stderr.printf("***START of topic\n")
  PP::pp(t,$stderr)
  $stderr.printf("***END of topic\n")
  # A topic is answered in the time period if and only if:
  # the first status_update_time to be "complete" is within in the time period
  # SMALL BUG: this fails if MongoDB was updated more than a day AFTER the topic was marked solved in Get Satisfaction 
  # LUCKILY this only happens with very old solved topics and is therefore rare
  sj = t["synthetic_status_journal"].detect {|status_journal|status_journal["status"] == "complete" }
  if sj && (sj["status_update_time"] <=> metrics_start) >= 0 && 
       (sj["status_update_time"] <=> metrics_stop) == -1
    $stderr.printf("SOLVED topic in time period title:%s url:%s\n",t["subject"].gsub(","," - ")[0..79],t["at_sfn"])
    personPlusSolvedURLs = personPlusSolvedURLs + "<li>Please contact:"+"<a href=\""+t["author"]["at_sfn"]+
      "\">"+t["author"]["canonical_name"]+"</a> about:"+
      "<a href=\""+ t["at_sfn"] + "\">"+t["subject"]+"</a></li>"
  end
end # topic iterator
personPlusSolvedURLs = personPlusSolvedURLs + "</ol>"

email_config = ParseConfig.new('email.conf').params
from = email_config['from_address']
to = email_config['to_address']
p = email_config['p']
subject = "People whose topics were solved FROM: %d.%d.%d back %d days" % [ARGV[0],ARGV[1],ARGV[2],ARGV[3]]
content = <<EOF
From: #{from}
To: #{to}
MIME-Version: 1.0
Content-type: text/html
subject: #{subject}
Date: #{Time.now.rfc2822}

<h3>People whose topics were marked solved</h3>
#{personPlusSolvedURLs}

EOF
print 'content', content

Net::SMTP.enable_tls(OpenSSL::SSL::VERIFY_NONE)  
Net::SMTP.start('smtp.gmail.com', 587, 'gmail.com', from, p, :login) do |smtp| 
  smtp.send_message(content, from, to)
end
