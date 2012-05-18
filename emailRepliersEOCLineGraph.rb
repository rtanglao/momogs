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
require 'cgi'
require 'gruff'

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

def  increment_num_replies_and_save_topic_link(topic, reply, contributors)
  author = reply["author"]["canonical_name"]
  c = contributors.detect {|c|c[:author] == author}
  if !c.nil?
    $stderr.printf("FOUND author:%s! Incrementing num_replies:%d\n", author,c[:num_replies]) 
    c[:num_replies] += 1
    c[:reply_hh][reply["created_at"].utc.hour] += 1
    existing_link = c[:links].detect{|l|l["url"] == topic["at_sfn"]}
    if existing_link.nil?
      c[:links].push({"url"=> topic["at_sfn"], "title" => topic["subject"][0..66]})
    end
  else
    $stderr.printf("DID NOT FIND author:%s! Adding Author and title:%s, setting num_replies to 1\n", 
      author, topic["subject"]) 
    contributor_array = contributors.push({:author => author,:num_replies => 1, :links => [], :reply_hh => Array.new(24,0) })
    contributor_array[-1][:links].push({"url"=> topic["at_sfn"], "title" => topic["subject"][0..66]})
    contributor_array[-1][:reply_hh][reply["created_at"].utc.hour] = 1
  end
  return contributors   
end

employees_or_champions = []

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
      $stderr.printf("IN time period, author:%s has a reply id:%d\n", author, r["id"])
      if  r["author"]["employee"] || r["author"]["champion"]
        employees_or_champions = increment_num_replies_and_save_topic_link(t, r, employees_or_champions)
      end 
    else
      $stderr.printf("NOT in time period, reply:%d\n", r["id"])
    end      
  end
end

employees_or_champions = employees_or_champions.sort{|b,c|c[:num_replies]<=>b[:num_replies]}

pp employees_or_champions.first(10)

data = []
legend = []

g = Gruff::Line.new
g.title = "EOC Replies " + metrics_start.year.to_s + "/" + metrics_start.month.to_s + "/" + metrics_start.day.to_s +
           " " + metrics_start.hour.to_s + ":00:00" +
           "TO:" +
           metrics_stop.hour.to_s + ":59:59"
start_hour = metrics_stop.utc.hour
$stderr.printf("start_hour:%d\n", start_hour)
end_hours = [ start_hour, (start_hour - 4) % 24, (start_hour - 8) % 24, (start_hour - 12) % 24, 
                   (start_hour - 16) % 24, (start_hour - 20) % 24].reverse
pp end_hours

employees_or_champions.first(5).each do |eoc|
  $stderr.printf("author:%s\n", eoc[:author])
  sorted_eoc = []
  start_hour_index = start_hour
  for i in 0..23
    sorted_eoc[i] = eoc[:reply_hh][start_hour_index]
    start_hour_index = (start_hour_index - 1) % 24
  end
  sorted_eoc.reverse!
  g.data(eoc[:author], sorted_eoc)
  pp eoc[:links]
end

g.labels = {4 => end_hours[0].to_s, 8  => end_hours[1].to_s, 
            12 => end_hours[2].to_s, 16 => end_hours[3].to_s, 
            20 => end_hours[4].to_s, 24 => end_hours[5].to_s}

g.write('eoc_replies.png')


# email_config = ParseConfig.new('email2.conf').params
# from = email_config['from_address']
# to = email_config['to_address'].split(",")
# p = email_config['p']
 


