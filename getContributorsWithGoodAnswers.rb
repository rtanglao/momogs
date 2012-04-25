#!/usr/bin/env ruby
require 'rubygems'
require 'json'
require 'pp'
require 'date'
require 'time'
require 'mongo'
require 'cgi'
require 'tlsmail'
require 'parseconfig'
 
if ARGV.length < 6
  puts "usage: #{$0} yyyy mm dd yyyy mmm dd"
  exit
end
 
metrics_start = Time.utc(ARGV[0], ARGV[1], ARGV[2], 0, 0)
metrics_stop = Time.utc(ARGV[3], ARGV[4], ARGV[5], 23, 59)

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

def createLinkWithLinktext(url, title, linktext, length)
  return "<a title=\""+CGI.escapeHTML(title)+"\""+
     " href=\""+ url + "\">"+CGI.escapeHTML(linktext[0..length-1])+"</a>"
end
def createLink(url, title, length)
  return "<a title=\""+CGI.escapeHTML(title) + "\""+
     " href=\""+ url + "\">" + CGI.escapeHTML(title[0..length-1]) + "</a>"
end

contributors = []
topicsColl.find({"reply_array" => { "$elemMatch"  => { "created_at" =>  {"$gte" => metrics_start, "$lte" => metrics_stop }}}},
                :fields => ["at_sfn", "id", "reply_count", "reply_array", "subject"]
                ).each do |t|
  $stderr.printf("topic:%d, reply_count:%d\n", t["id"], t["reply_count"])
  url = t["at_sfn"].gsub!("http:/", "https:/")
  t["reply_array"].each do |r|
    created_at = r["created_at"]
    $stderr.printf("CHECKING reply:%d by author:%s\n", r["id"],r["author"]["canonical_name"])
    if ((created_at <=> metrics_start) >= 0) && ((created_at <=> metrics_stop) <= 0)
      $stderr.printf("reply IN time period star_promoted:%s, company_promoted:%s star_count:%d\n",
        r["star_promoted"], r["company_promoted"], r["star_count"] )
      if !r["star_promoted"] && !r["company_promoted"] && !(r["star_count"] > 0)
        break
      end
      author = r["author"]["canonical_name"]
      $stderr.printf("IN time period, author:%s has a star promoted or company promoted or starred reply id:%d\n", author, r["id"])
      author_found = false
      contributors.each do |c|
        $stderr.printf("contributor loop:author:%s\n",c[:author])
        if c[:author] == author
          if !c[:topic_urls].include?(url)
            c[:num_topics] += 1
            $stderr.printf("FOUND author:%s! Incrementing num_topics:%d\n", author,c[:num_topics]) 
            c[:topic_urls].push(url)
            c[:topic_subjects].push(t["subject"][0..66])
          end
          author_found = true
          break
        end
      end # contributors
      if !author_found
        $stderr.printf("DID NOT FIND author:%s! Adding Author, setting num_topics to 1\n", author) 
        contributors.push({:author => author,:num_topics => 1, :topic_urls => [url], :topic_subjects => [t["subject"][0..66]]})
      end
    else
      $stderr.printf("NOT in time period, reply:%d\n", r["id"])
    end      
  end
end

contributors = contributors.sort_by{|c|c[:num_topics]}
contributor_reply_html = "<ol>"
contributors.reverse.each do |row|
  contributor_reply_html += "<li>" + row[:num_topics].to_s + ",&nbsp;" +
    createLink("https://getsatisfaction.com/people/" + CGI.escapeHTML(row[:author]), row[:author], 24) + ":"
  row[:topic_urls].each_with_index do |topic_url,i|
    contributor_reply_html += createLinkWithLinktext(topic_url, row[:topic_subjects][i],
        (i+1).to_s, (i+1).to_s.length) + ":"
  end
  contributor_reply_html += "</li>\n"
end
contributor_reply_html += "</ol>\n"

email_config = ParseConfig.new('email.conf').params
from = email_config['from_address']
to = email_config['to_address'].split(",")
p = email_config['p']
subject = "Thunderbird Contributor ANSWER Report FROM: %d.%d.%d TO: %d.%d.%d generated:%s" % [ARGV[0],ARGV[1],ARGV[2],ARGV[3], ARGV[4], ARGV[5], Time.now]
content = <<EOF
From: #{from}
To: #{email_config['to_address']}
MIME-Version: 1.0
content-type: text/html; charset=utf-8
subject: #{subject}
Date: #{Time.now.rfc2822}

<h3>Contributors w/starred replies, promoted replies or company promoted replies</h4>
#{contributor_reply_html}
EOF
print 'content', content

Net::SMTP.enable_tls(OpenSSL::SSL::VERIFY_NONE)
Net::SMTP.start('smtp.gmail.com', 587, 'gmail.com', from, p, :login) do |smtp|
  smtp.send_message(content, from, to)
end
