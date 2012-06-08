#!/usr/bin/env ruby
require 'rubygems'
require 'json'
require 'time'
require 'date'
require 'parseconfig'
require 'mongo'
require 'sparklines'
require 'gmail'
require 'createLinkFunctions.rb'
require 'RMagick'

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

active_topics = []

topicsColl.find({"reply_array" => { "$elemMatch"  => { "created_at" =>  {"$gte" => metrics_start, "$lte" => metrics_stop }}}},
                :fields => ["at_sfn", "id", "reply_count", "reply_array", "subject"]
                ).each do |t|
  url = t["at_sfn"]
  $stderr.printf("topic url:%s id:%d, reply_count:%d subject:%s\n", url, t["id"], t["reply_count"], t["subject"])
  t["reply_array"].each do |r|
    created_at = r["created_at"]
    $stderr.printf("CHECKING reply:%d by author:%s created_at:%s\n", r["id"],r["author"]["canonical_name"], created_at.to_s)
    if ((created_at <=> metrics_start) >= 0) && ((created_at <=> metrics_stop) <= 0)
      existing_active_topic = active_topics.detect {|t1|t1[:url] == url}
      if existing_active_topic.nil?
        $stderr.printf("topic url:%s id:%d,  subject:%s\n", url, t["id"], t["subject"])
        active_topics.push({:url => url, :title => t["subject"], :id => t["id"],
                             :num_replies => 1, :reply_hh => Array.new(24,0) })
        active_topics[-1][:reply_hh][created_at.utc.hour] = 1
      else
        existing_active_topic[:num_replies] += 1
        existing_active_topic[:reply_hh][created_at.utc.hour] += 1
      end
    else
      $stderr.printf("NOT in time period, reply:%d\n", r["id"])
    end      
  end
end

active_topics = active_topics.sort{|b,c|c[:num_replies]<=>b[:num_replies]}

start_hour = metrics_stop.utc.hour
$stderr.printf("start_hour:%d\n", start_hour)
end_hours = [ start_hour, (start_hour - 4) % 24, (start_hour - 8) % 24, (start_hour - 12) % 24, 
                   (start_hour - 16) % 24, (start_hour - 20) % 24].reverse

line_colour = ['black', 'red', 'orange', 'green', 'blue']
active_topics.first(5).each_with_index do |t,index|
  filename = (index + 1).to_s + ".png"
  $stderr.printf("url:%s\n", t[:url])
  sorted_reply_count = []
  start_hour_index = start_hour
  for i in 0..23
    sorted_reply_count[i] = t[:reply_hh][start_hour_index]
    start_hour_index = (start_hour_index - 1) % 24
  end
  sorted_reply_count.reverse!
  Sparklines.plot_to_file(filename, sorted_reply_count, :type => "smooth", :line_color => line_colour[index],
   :height => 50, :step => 10)
end

ilg = Magick::ImageList.new
1.upto(5) {|i| filename = i.to_s + ".png"
  ilg.push(Magick::Image.read(filename).first)}
ilg.append(true).write("active_hourly_topics_spark.png")

active_topics_html = "<ol>"
active_topics.first(5).each do |t|
  active_topics_html += "<li>" + t[:num_replies].to_s + ",&nbsp;" + 
    createLink(t[:url], t[:title], 80)
  active_topics_html += "</li>\n"
end
active_topics_html += "</ol>\n"

email_config = ParseConfig.new('emailgraphicblog.conf').params
from = email_config['from_address']
to_address = email_config['to_address'].split(",")
p = email_config['p']
subject_str = "Top 5 active by hour" + metrics_start.year.to_s + "/" + metrics_start.month.to_s + "/" + metrics_start.day.to_s +
      " " + metrics_start.hour.to_s + ":00:00" +
      "TO:" +  metrics_stop.year.to_s + "/" + metrics_stop.month.to_s + "/" + metrics_stop.day.to_s + " " +
      metrics_stop.hour.to_s + ":59:59"    
Gmail.connect(from, p) do |gmail|
  gmail.deliver do
    to to_address
    subject subject_str
    html_part do
      body active_topics_html + "<br>\n#hourlyTop5ActiveTopicsSpark \n#thunderbird \n#mozilla \n#thunderbirdmetrics "
    end
    add_file "active_hourly_topics_spark.png"
  end
end


 


