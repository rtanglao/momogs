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

metrics_start = Time.utc(ARGV[0], ARGV[1], ARGV[2], 0, 0)
metrics_stop =  Time.utc(ARGV[3], ARGV[4], ARGV[5], 23, 59)

executable_name = $0.gsub(".rb","")

start_date = ARGV[0] + ARGV[1] + ARGV[2]

def  increment_num_replies_and_save_topic_link(topic, reply, contributors)
  author = reply["author"]["canonical_name"]
  c = contributors.detect {|c|c[:author] == author}
  if !c.nil?
    $stderr.printf("FOUND author:%s! Incrementing num_replies:%d\n", author,c[:num_replies]) 
    c[:num_replies] += 1
    c[:reply_hh][reply["created_at"].hour] += 1
    existing_link = c[:links].detect{|l|l["url"] == topic["at_sfn"]}
    if existing_link.nil?
      c[:links].push({"url"=> topic["at_sfn"], "title" => topic["subject"][0..66]})
    end
  else
    $stderr.printf("DID NOT FIND author:%s! Adding Author and title:%s, setting num_replies to 1\n", 
      author, topic["subject"]) 
    contributor_array = contributors.push({:author => author,:num_replies => 1, :links => [], :reply_hh => Array.new(24,0) })
    contributor_array[-1][:links].push({"url"=> topic["at_sfn"], "title" => topic["subject"][0..66]})
    contributor_array[-1][:reply_hh][reply["created_at"].hour] = 1
  end
  return contributors   
end

employees_or_champions = []
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
      $stderr.printf("IN time period, author:%s has a reply id:%d\n", author, r["id"])
      if  r["author"]["employee"] || r["author"]["champion"]
        employees_or_champions = increment_num_replies_and_save_topic_link(t, r, employees_or_champions)
      else
        non_employees_or_champions  = increment_num_replies_and_save_topic_link(t, r, non_employees_or_champions)
      end 
    else
      $stderr.printf("NOT in time period, reply:%d\n", r["id"])
    end      
  end
end


employees_or_champions = employees_or_champions.sort{|b,c|c[:num_replies]<=>b[:num_replies]}
non_employees_or_champions = non_employees_or_champions.sort{|b,c|c[:num_replies]<=>b[:num_replies]}

pp employees_or_champions.first(10)

data = []
legend = []
# employees_or_champions.first(10).each do |eoc|
#   data.push(eoc[:reply_hh])
#   legend.push(eoc[:author])
# end

g = Gruff::Line.new
g.title = "Contributor Replies FROM:"+ARGV[0]+"."+ARGV[1]+'.'+ARGV[2]+" TO:"+ARGV[3]+"."+ARGV[4]+'.'+ARGV[5]

employees_or_champions.first(10).each do |eoc|
  $stderr.printf("author:%s\n", eoc[:author])
  g.data(eoc[:author], eoc[:reply_hh])
end

g.labels = {0 => '0000', 8 => '0700',  12 => '1100', 16 => '1500', 20 => '1900', 24=>'2300'}

g.write('contributor_replies.png')

# Gchart.line(:size => '640x480', 
#             :title => "Contributor Replies FROM:"+ARGV[0]+"."+ARGV[1]+'.'+ARGV[2]+" TO:"+ARGV[3]+"."+ARGV[4]+'.'+ARGV[5],
#             :bg => 'efefef',
#             :legend => legend,
#             :data => data,
#             :format => 'file', :filename => 'contributor_replies.png')
# print "non employees or champions"

# pp non_employees_or_champions.first(10)


# email_config = ParseConfig.new('email2.conf').params
# from = email_config['from_address']
# to = email_config['to_address'].split(",")
# p = email_config['p']



