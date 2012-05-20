#!/usr/bin/env ruby
require 'rubygems'
require 'json'
require 'time'
require 'date'
require 'parseconfig'
require 'mongo'
require 'gruff'
require 'gmail'
require 'createLinkFunctions.rb'
require 'getContributorHtml.rb'
require 'incrementNumRepliesAndSaveTopicLink.rb'

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

t = Time.now.gmtime
metrics_stop = Time.utc(t.year,t.month, t.day, t.hour, 0) - 1
metrics_start = metrics_stop - (23 * 3600) - (59 * 60) - 59
$stderr.printf("from:%s to:%s\n", metrics_start.to_s, metrics_stop.to_s)

non_employees_or_champions = []

topicsColl.find({"reply_array" => { "$elemMatch"  => { "created_at" =>  {"$gte" => metrics_start, "$lte" => metrics_stop }}}},
                :fields => ["at_sfn", "id", "reply_count", "reply_array", "subject"]
                ).each do |t|
  $stderr.printf("topic:%d, reply_count:%d\n", t["id"], t["reply_count"])
  url = t["at_sfn"]
  t["reply_array"].each do |r|
    created_at = r["created_at"]
    $stderr.printf("CHECKING reply:%d by author:%s\n", r["id"],r["author"]["canonical_name"])
    if ((created_at <=> metrics_start) >= 0) && ((created_at <=> metrics_stop) <= 0)
      author = r["author"]["canonical_name"]
      $stderr.printf("IN time period, author:%s has a reply id:%d at:%s\n", author, r["id"], created_at.to_s)
      if  !r["author"]["employee"] && !r["author"]["champion"]
        non_employees_or_champions = increment_num_replies_and_save_topic_link(t, r, non_employees_or_champions)
      end 
    else
      $stderr.printf("NOT in time period, reply:%d\n", r["id"])
    end      
  end
end

non_employees_or_champions = non_employees_or_champions.sort{|b,c|c[:num_replies]<=>b[:num_replies]}

data = []
legend = []

g = Gruff::Line.new
g.theme_pastel
g.title = "NONEOC Replies " + metrics_start.year.to_s + "/" + metrics_start.month.to_s + "/" + metrics_start.day.to_s +
           " " + metrics_start.hour.to_s + ":00" +
           "TO:" +
           metrics_stop.hour.to_s + ":59"
start_hour = metrics_stop.utc.hour
$stderr.printf("start_hour:%d\n", start_hour)
end_hours = [ start_hour, (start_hour - 4) % 24, (start_hour - 8) % 24, (start_hour - 12) % 24, 
                   (start_hour - 16) % 24, (start_hour - 20) % 24].reverse

non_employees_or_champions.first(5).each do |non_eoc|
  $stderr.printf("author:%s\n", non_eoc[:author])
  sorted_non_eoc = []
  start_hour_index = start_hour
  for i in 0..23
    sorted_non_eoc[i] = non_eoc[:reply_hh][start_hour_index]
    start_hour_index = (start_hour_index - 1) % 24
  end
  sorted_non_eoc.reverse!
  g.data(non_eoc[:author], sorted_non_eoc)
end

g.labels = {3 => end_hours[0].to_s, 7  => end_hours[1].to_s, 
            11 => end_hours[2].to_s, 15 => end_hours[3].to_s, 
            19 => end_hours[4].to_s, 23 => end_hours[5].to_s}

g.write('non_eoc_hourly_replies.png')

non_eoc_reply_html = get_html_for_contributors(non_employees_or_champions.first(5))
email_config = ParseConfig.new('email2.conf').params
from = email_config['from_address']
to_address = email_config['to_address'].split(",")
p = email_config['p']
subject_str = "NONEOC Replies " + metrics_start.year.to_s + "/" + metrics_start.month.to_s + "/" + metrics_start.day.to_s +
      " " + metrics_start.hour.to_s + ":00:00" +
      "TO:" +  metrics_stop.year.to_s + "/" + metrics_stop.month.to_s + "/" + metrics_stop.day.to_s + " " +
      metrics_stop.hour.to_s + ":59:59"    
Gmail.connect(from, p) do |gmail|
  gmail.deliver do
    to to_address
    subject subject_str
    html_part do
      body non_eoc_reply_html + "<br>\n#NONeochourlyreplies \n#thunderbird \n#mozilla \n#thunderbirdmetrics "
    end
    add_file "non_eoc_hourly_replies.png"
  end
end


 


