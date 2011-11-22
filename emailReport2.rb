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

providers = []
regexes = []
isp_regexes = []
isp_providers = []

def get_html_for_contributors(contributors)
  contributor_reply_html = "<ol>"
  contributors.each do |t|
    contributor_reply_html += "<li>" + t[:num_replies].to_s + ", " + 
      createLink("http://getsatisfaction.com/people/" + CGI.escapeHTML(t[:author]), t[:author], 24) + " "
    t[:links].each_with_index do |l,i|
      contributor_reply_html += createLinkWithLinktext(l["url"], l["title"],
        (i+1).to_s, (i+1).to_s.length) + " "              
    end
    contributor_reply_html += "</li>"
  end
  contributor_reply_html += "</ol>"
  return contributor_reply_html
end

def  increment_num_replies_and_save_topic_link(topic, reply, contributors)
  author = reply["author"]["canonical_name"]
  c = contributors.detect {|c|c[:author] == author}
  if !c.nil?
    $stderr.printf("FOUND author:%s! Incrementing num_replies:%d\n", author,c[:num_replies]) 
    c[:num_replies] += 1
    existing_link = c[:links].detect{|l|l["url"] == topic["at_sfn"]}
    if existing_link.nil?
      c[:links].push({"url"=> topic["at_sfn"], "title" => topic["subject"]})
    end
  else
    $stderr.printf("DID NOT FIND author:%s! Adding Author and title:%s, setting num_replies to 1\n", 
      author, topic["subject"]) 
    contributor_array = contributors.push({:author => author,:num_replies => 1, :links => []})
    contributor_array[-1][:links].push({"url"=> topic["at_sfn"], "title" => topic["subject"]})
  end
  return contributors   
end

def sanitize_tag(tag) 
  t = tag.gsub(" ", "_")
  return t.gsub(/[\.!\?]/, "")
end

def check_for_mentions(text, regexes, names_for_regexes)
  mentions = []
  regexes.each_with_index do |re,i|
    if re.match text 
      mentions.push(names_for_regexes[i])
    end
  end
  return mentions
end
def check_for_mentions_and_increment_count(text, subject, url, regexes, mentions_with_counts)
  regexes.each_with_index do |re,i|
    if re.match text 
      mentions_with_counts[i]["count"] += 1
      mentions_with_counts[i]["link_html"].push(createLinkWithLinktext(url, subject,  
        mentions_with_counts[i]["count"].to_s, mentions_with_counts[i]["count"].to_s.length))
    end
  end
  return mentions_with_counts
end
def createLinkWithLinktext(url, title, linktext, length)
  return "<a title=\""+CGI.escapeHTML(title)+"\""+
     " href=\""+ url + "\">"+CGI.escapeHTML(linktext[0..length-1])+"</a>"
end
def createLink(url, title, length)
  return "<a title=\""+CGI.escapeHTML(title) + "\""+
     " href=\""+ url + "\">" + CGI.escapeHTML(title[0..length-1]) + "</a>"
end

f = File.open("tag_stopwords.txt") or die "Unable to open tag_stopwords.txt..."
tag_stoplist = [] 
f.each_line {|line| tag_stoplist.push line.chomp}

f = File.open("mailProviderRegex.txt") or die "Unable to open mailProviderRegex.txt..."
mailProviderRegexStr = [] 
f.each_line {|line| mailProviderRegexStr.push line.split(',')}
regexes = mailProviderRegexStr.collect {|re_str|%r|#{re_str[0]}|}
providers =  mailProviderRegexStr.collect {|re_str|re_str[1]}

f = File.open("ispRegex.txt") or die "Unable to open ispRegex.txt..."
ispRegexStr = [] 
f.each_line {|line| ispRegexStr.push line.split(',')}
isp_regexes = ispRegexStr.collect {|re_str|%r|#{re_str[0]}|}
isp_providers =  ispRegexStr.collect {|re_str|re_str[1]}

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
    provider_mentions = check_for_mentions(fulltext_with_tags, regexes, providers)
    isp_mentions = check_for_mentions(fulltext_with_tags, isp_regexes, isp_providers)
    active_topics.push({:isp_mentions => isp_mentions, :provider_mentions => provider_mentions, 
      :reply_count => reply_count_for_time_period,:topic => t})
  end
end
active_topics = active_topics.sort_by{|h|h[:reply_count]}
active_html = ""
active_topics.reverse.first(20).each do |t|
  active_html += "<tr><td>"+
    t[:reply_count].to_s+"</td><td>"+ createLink(t[:topic]["at_sfn"], t[:topic]["subject"],40) + "</td><td>"
  t[:topic]["tags_array"].each do |tag|
    active_html += createLink("http://getsatisfaction.com/mozilla_messaging/tags/" + CGI.escapeHTML(sanitize_tag(tag)),
      tag, 16) + " "              
  end
  active_html += "</td><td>"
  t[:provider_mentions].each{|p| active_html += CGI.escapeHTML(p[0..15]) + " " }
  active_html += "</td><td>"
  t[:isp_mentions].each{|isp| active_html += CGI.escapeHTML(isp[0..15]) + " " }
  active_html += "</td></tr>"
end

# find active topics that were updated in the time period
# then calculate:
#   trending tags, mail providers, ISPs and proper nouns
provider_mention_counts = []
isp_mention_counts = []
tag_counts = {}
providers.each{|p| provider_mention_counts.push({"provider" => p, "count" => 0, 
                 "link_html" => []})}
isp_providers.each{|isp| isp_mention_counts.push({"isp" => isp, "count" => 0, 
                 "link_html" => []})}
topicsColl.find({"last_active_at" =>  
                  {"$gte" => metrics_start, "$lte" => metrics_stop }},
                  :fields => ["at_sfn", "fulltext_with_tags", 
                              "last_active_at", "subject", "tags_array"]
                ).sort([["last_active_at", Mongo::ASCENDING]]).each do |t|  
  provider_mention_counts = check_for_mentions_and_increment_count(t["fulltext_with_tags"], t["subject"], t["at_sfn"], 
    regexes, provider_mention_counts)
  isp_mention_counts = check_for_mentions_and_increment_count(t["fulltext_with_tags"], t["subject"], t["at_sfn"], 
    isp_regexes, isp_mention_counts)
  t["tags_array"].each do |tag|
    if tag_counts.has_key?(tag)
      tag_counts[tag]["count"] += 1
    else
      tag_counts[tag] = {"count"=> 1, "links" => []}
    end
    tag_counts[tag]["links"].push({"url" => t["at_sfn"], "title" => t["subject"]})
  end
end

sorted_tag_counts = tag_counts.sort{|p,q|q[1]["count"]<=>p[1]["count"]}
sorted_tag_counts.delete_if{|t|tag_stoplist.detect{|stop|stop == t[0]}}
provider_mention_counts = provider_mention_counts.sort{|p,q|q["count"]<=>p["count"]}
isp_mention_counts = isp_mention_counts.sort{|p,q|q["count"]<=>p["count"]}
tag_html = "<ol>"
sorted_tag_counts.first(20).each do |t|
  tag_html += "<li>" + t[1]["count"].to_s + ", "
  sanitized_tag = sanitize_tag(t[0])
  tag_html +=  
    createLinkWithLinktext("http://getsatisfaction.com/mozilla_messaging/tags/" +
      CGI.escapeHTML(sanitized_tag), t[0], t[0], 16) + ":" 
    t[1]["links"].each_with_index do |tag_info,i|
      tag_html += createLinkWithLinktext(tag_info["url"], tag_info["title"],
        (i+1).to_s, (i+1).to_s.length) + " "
    end
  tag_html += "</li>"
end
tag_html += "</ol>"

mailprovider_html = "<ol>"
provider_mention_counts.each_with_index do |p,i|
  mailprovider_html += "<li>"
  mailprovider_html +=  CGI.escapeHTML(p["provider"]) + ":" + p["count"].to_s + " "
  p["link_html"].each {|l| mailprovider_html = mailprovider_html + l + " " }
  mailprovider_html += "</li>"
end
mailprovider_html += "</ol>"

isp_html = "<ol>"
isp_mention_counts.each_with_index do |isp,i|
  isp_html += "<li>"
  isp_html += CGI.escapeHTML(isp["isp"]) + ":" + isp["count"].to_s + " "
  isp["link_html"].each {|l| isp_html = isp_html + l + " " }
  isp_html += "</li>"
end
isp_html += "</ol>"

created_topics = []
provider_mentions = []
isp_mentions = []
# get topics created in the time period and get tags, mail providers, isps
topicsColl.find({"created_at" =>  
                  {"$gte" => metrics_start, "$lte" => metrics_stop }},
                  :fields => ["at_sfn", "fulltext_with_tags", 
                               "subject", "tags_array"]
                ).sort([["created_at", Mongo::ASCENDING]]).each do |t|  
  url = t["at_sfn"]
  subject = t["subject"]
  fulltext_with_tags = t["fulltext_with_tags"]
  tags_array = t["tags_array"]
  provider_mentions = check_for_mentions(fulltext_with_tags, regexes, providers)
  isp_mentions = check_for_mentions(fulltext_with_tags, isp_regexes, isp_providers)
  created_topics.push({:isp_mentions => isp_mentions, :provider_mentions => provider_mentions, 
      :reply_count => 0,:topic => t})
end

created_html = ""
created_topics.each_with_index do |t,i|
  created_html += "<tr><td>"+
   (i+1).to_s+".</td><td>"+ createLink(t[:topic]["at_sfn"], t[:topic]["subject"],40) + "</td><td>"
  t[:topic]["tags_array"].each do |tag|
    created_html += createLink("http://getsatisfaction.com/mozilla_messaging/tags/" +
      CGI.escapeHTML(sanitize_tag(tag)), tag, 16) + " "              
  end
  created_html += "</td><td>"
  t[:provider_mentions].each{|p| created_html += CGI.escapeHTML(p[0..15]) + " " }
  created_html += "</td><td>"
  t[:isp_mentions].each{|isp| created_html += CGI.escapeHTML(isp[0..15]) + " " }
  created_html += "</td></tr>"
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

eoc_reply_html = get_html_for_contributors(employees_or_champions.first(20))
non_eoc_reply_html = get_html_for_contributors(non_employees_or_champions.first(20))

email_config = ParseConfig.new('email2.conf').params
from = email_config['from_address']
to = email_config['to_address'].split(",")
p = email_config['p']
subject = "Thunderbird Support Report FROM: %d.%d.%d TO: %d.%d.%d generated:%s" % [ARGV[0],ARGV[1],ARGV[2],ARGV[3], ARGV[4], ARGV[5], Time.now]
content = <<EOF
From: #{from}
To: #{email_config['to_address']}
MIME-Version: 1.0
Content-type: text/html; charset=utf-8
subject: #{subject}
Date: #{Time.now.rfc2822}

<h3>TOC</h3>
<ul>
<li><a href="#trending">Trending FROM:#{ARGV[0]}.#{ARGV[1]}.#{ARGV[2]} TO:#{ARGV[3]}.#{ARGV[4]}.#{ARGV[5]}</a></li>
<li><a href="#repliers">Top Repliers FROM:#{ARGV[0]}.#{ARGV[1]}.#{ARGV[2]} TO:#{ARGV[3]}.#{ARGV[4]}.#{ARGV[5]}</a></li>
<li><a href="#active">Active FROM:#{ARGV[0]}.#{ARGV[1]}.#{ARGV[2]} TO:#{ARGV[3]}.#{ARGV[4]}.#{ARGV[5]}</a></li>
<li><a href="#created">Created FROM:#{ARGV[0]}.#{ARGV[1]}.#{ARGV[2]} TO:#{ARGV[3]}.#{ARGV[4]}.#{ARGV[5]}</a></li>
</ul>

<a name="trending"></a>
<h3>Trending tags, mail providers, and ISPs</h3>
<h4>Mail Providers</h4>
#{mailprovider_html}
<h4>ISPs</h4>
#{isp_html}
<h4>Tags</h4>
#{tag_html}

<a name="repliers"></a>
<h3>Top Repliers</h3>
<h4>Top Champion and Employee Repliers</h4>
#{eoc_reply_html}
<h4>Top NON Champion and Employee Repliers</h4>
#{non_eoc_reply_html}

<a name="active"></a>
<h3>Get Satisfaction Thunderbird Active Topics FROM:#{ARGV[0]}.#{ARGV[1]}.#{ARGV[2]} TO:#{ARGV[3]}.#{ARGV[4]}.#{ARGV[5]}</h3>
<p>
<b>Active</b> means topics with replies during FROM:#{ARGV[0]}.#{ARGV[1]}.#{ARGV[2]} TO:#{ARGV[3]}.#{ARGV[4]}.#{ARGV[5]}
</p>
<table border="1" bgcolor="gray">
<tr>
<th>replies</th>
<th>url</th>
<th>tags</th>
<th>mail providers</th>
<th>ISPs</th>
</tr>
#{active_html}
</table>

<a name="created"></a>
<h3>Get Satisfaction Thunderbird Topics Created FROM:#{ARGV[0]}.#{ARGV[1]}.#{ARGV[2]} TO:#{ARGV[3]}.#{ARGV[4]}.#{ARGV[5]}</h3>

<table border="1">
<tr>
<th>topic#</th>
<th>url</th>
<th>tags</th>
<th>mail providers</th>
<th>ISPs</th>
</tr>
#{created_html}
</table>

EOF
print 'content', content

Net::SMTP.enable_tls(OpenSSL::SSL::VERIFY_NONE)  
Net::SMTP.start('smtp.gmail.com', 587, 'gmail.com', from, p, :login) do |smtp| 
  smtp.send_message(content, from, to)
end


