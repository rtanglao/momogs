#!/usr/bin/env ruby
require 'json'
require 'net/http'
require 'pp'
require 'Time'
require 'tlsmail'
require 'time'
require 'parseconfig'

def getResponse(url)

  http = Net::HTTP.new("api.getsatisfaction.com",80)
  http.read_timeout = 160 # seconds
  http.open_timeout = 160

  url = "/" + url 

  resp, data = http.get(url, nil)
   
  if resp.code != "200"
    puts "Error: #{resp.code} from:#{url}"
    raise JSON::ParserError # This is a kludge. Should return a proper exception instead!
    return ""
  end

  result = JSON.parse(data)
  return result
end

if ARGV.length < 6
  puts "usage: #{$0} yyyy mm dd yyyy mmm dd"
  exit
end

metrics_start = Time.utc(ARGV[0], ARGV[1], ARGV[2], 0, 0)
metrics_start -= 1
metrics_stop =  Time.utc(ARGV[3], ARGV[4], ARGV[5], 23, 59)
metrics_stop += 1
roland_replies = 0
non_roland_replies = 0
topic_page = 0
end_program = false
numRepliesByTopic={}

while true
  topic_page += 1
  skip = false
  topic_url = "products/mozilla_thunderbird/topics.json?sort=recently_active&page=" << "%d" % topic_page << "&limit=30"
  printf(STDERR, "topic_url")
  begin
    topics = getResponse(topic_url)
  rescue JSON::ParserError
    printf(STDERR, "Parser error in topic:%s\n", topic_url)

    skip = true
  end
  if skip
    skip = false
    next
  end
  topics["data"].each do|topic|
    last_active_at = Time.parse(topic["last_active_at"])
    last_active_at = last_active_at.utc
    printf(STDERR, "TOPIC last_active_at:%s\n", last_active_at)

    if (last_active_at <=> (metrics_start + 1)) == -1 
      printf(STDERR, "ending program\n")
      end_program = true
      break
    end

    printf(STDERR, "START*** of topic\n")
    PP::pp(topic,$stderr)
    printf(STDERR, "\nEND*** of topic\n")
    reply_count = topic["reply_count"]
    printf(STDERR, "reply_count:%d\n", reply_count)
    reply_page = 1
    if reply_count != 0
      begin # while reply_count > 0
        get_reply_url = "topics/" + topic["slug"] + "/replies.json?sort=recently_created&page=" << "%d" % reply_page << "&limit=30"     
        canonical_topic_url = "http://getsatisfaction.com/mozilla_messaging/topics/" + topic["slug"]

        PP::pp(get_reply_url, $stderr)
        skip = false
        begin 
          replies = getResponse(get_reply_url)
        rescue JSON::ParserError
          printf(STDERR, "Parser error in reply:%s\n", get_reply_url)
          reply_count -= 30
          reply_page += 1
          skip = true
        end
        if skip
          skip = false
          next
        end
        replies["data"].each do|reply|
    
          printf(STDERR, "START*** of reply\n")
          PP::pp(reply, $stderr)

          printf(STDERR, "\nEND*** of reply\n")

          author = reply["author"]["name"]
          reply_created_time = Time.parse(reply["created_at"])
          reply_created_time = reply_created_time.utc
          topic_id = reply["topic_id"]
          reply_id = reply["id"]

          printf(STDERR, "RRR: reply created time:%s\n", reply_created_time)

          if (reply_created_time <=> metrics_start) == 1 &&
             (reply_created_time <=> metrics_stop) == -1
            puts "Reply created by:#{author} at:#{reply_created_time} topic:#{topic_id} reply:#{reply_id} IN Time Window"
            if numRepliesByTopic.has_key?(canonical_topic_url)
              numRepliesByTopic[canonical_topic_url] += 1
            else
              numRepliesByTopic[canonical_topic_url] = 1
            end
          else
            printf(STDERR,"Reply created by:%s at:%s topic:%s reply:%s NOT IN Time Window\n",author, reply_created_time, topic_id, reply_id)
          end
        end # replies ... do
        reply_count -= 30
        reply_page += 1
      end while reply_count > 0
    end
  end 
  if end_program
    break
  end
end

sorted_array=[]
index = 0
numRepliesByTopic.sort{|canonical_topic_url,numReplies| canonical_topic_url[1]<=>numReplies[1]}.each { |elem|
  puts "#{elem[1]}, #{elem[0]}"
  sorted_array[index]={}
  sorted_array[index]["numReplies"]=elem[1]
  sorted_array[index]["topic_url"]=elem[0]
  index += 1
}
executable_name = $0.gsub(".rb","")
printf(STDERR, "CSV filename:%s.%s%s%s.%s%s%s.csv\n",executable_name, ARGV[0],ARGV[1],ARGV[2],ARGV[3],ARGV[4],ARGV[5])

csv_file = File.new(executable_name + '.' + ARGV[0]+ARGV[1]+ARGV[2]+"."+ARGV[3]+ARGV[4]+ARGV[5] + ".csv", "w")

reverse_sorted=[]
index = 0
sorted_array.reverse.each{|row|
  csv_file.puts "#{row['numReplies']},#{row['topic_url']}"
  reverse_sorted[index]=row
  index += 1
}

csv_file.close
start_date = ARGV[0] + ARGV[1] + ARGV[2]
start_date_str = ARGV[0] + " " + ARGV[1] + " " + ARGV[2]

end_date = ARGV[3] + ARGV[4] + ARGV[5]
end_date_str = ARGV[3] + " " + ARGV[4] + " " + ARGV[5]

stderrfile = 'getcontributors.' + start_date + '.' + end_date + '.stderr'
stdoutfile = 'getcontributors.' + start_date + '.' + end_date + '.stdout'
csvfile = "getcontributors.%s%s%s.%s%s%s.csv" % [ARGV[0],ARGV[1],ARGV[2],ARGV[3],ARGV[4],ARGV[5]]
printf(STDERR, "CONTRIBUTORS CSV:%s\n", csvfile)

`./getcontributors.rb #{start_date_str} #{end_date_str} 2>#{stderrfile} 1>#{stdoutfile}`

contributors=""
if File::exists?(csvfile) && File.size(csvfile) > 0
  File.open(csvfile, "r") do |infile|
    while (line = infile.gets)
      contributors = contributors + line
    end
  end
end
printf(STDERR, "CONTRIBUTORS:%s\n", contributors)
contributors.gsub!("\n","<br />")

gethappy_stderrfile = 'gethappy.' + start_date + '.' + end_date + '.stderr'
gethappy_stdoutfile = 'gethappy.' + start_date + '.' + end_date + '.stdout'
`./gethappykludged.rb #{start_date_str} #{end_date_str} 2>#{gethappy_stderrfile} 1>#{gethappy_stdoutfile}`
top_10_repliers = `tail -n 10 #{gethappy_stdoutfile}`
top_10_repliers.gsub!("\n","<br />")

getrandom_stderrfile = 'getrandom.' + start_date + '.' + end_date + '.stderr'
getrandom_stdoutfile = 'getrandom.' + start_date + '.' + end_date + '.stdout'
random_csvfile = "getrandom.%s%s%s.%s%s%s.csv" % [ARGV[0],ARGV[1],ARGV[2],ARGV[3],ARGV[4],ARGV[5]]
printf(STDERR, "RANDOM CSV:%s\n", random_csvfile)
# get 5 random topics
`./getrandom.rb #{start_date_str} #{end_date_str} 5 2>#{getrandom_stderrfile} 1>#{getrandom_stdoutfile}`

five_random_topics = "<ul>"
if File::exists?(random_csvfile) && File.size(random_csvfile) > 0
  File.open(random_csvfile, "r") do |infile|
    while (line = infile.gets)
      if line != "\n"
        line.gsub!("\n","")
        line_withouthttp = line.gsub("http://getsatisfaction.com/mozilla_messaging/topics/","")
        five_random_topics = five_random_topics + "<li><a href=\""+ line + "\">"+line_withouthttp+"</a></li>"
      end
    end
  end
end
five_random_topics = five_random_topics + "</ul>"

geturls_stderrfile = 'geturls.' + start_date + '.' + end_date + '.stderr'
geturls_stdoutfile = 'geturls.' + start_date + '.' + end_date + '.stdout'
urls_csvfile = "gettopicURLs.%s%s%s.%s%s%s.csv" % [ARGV[0],ARGV[1],ARGV[2],ARGV[3],ARGV[4],ARGV[5]]
printf(STDERR, "TOPIC URLs CSV:%s\n", urls_csvfile)
# get 5 random topics
`./gettopicURLs.rb #{start_date_str} #{end_date_str}  2>#{geturls_stderrfile} 1>#{geturls_stdoutfile}`
topicURLs = "<ol>"
if File::exists?(urls_csvfile) && File.size(urls_csvfile) > 0
  File.open(urls_csvfile, "r") do |infile|
    while (line = infile.gets)
      if line != "\n"
        line.gsub!("\n","")
        line_withouthttp = line.gsub("http://getsatisfaction.com/mozilla_messaging/topics/","")
        topicURLs = topicURLs + "<li><a href=\""+ line + "\">"+line_withouthttp+"</a></li>"
      end
    end
  end
end
topicURLs = topicURLs + "</ol>"

email_config = ParseConfig.new('email.conf').params
from = email_config['from_address']
to = email_config['to_address']
p = email_config['p']
subject = "MoMo Support Report FROM: %d.%d.%d TO: %d.%d.%d" % [ARGV[0],ARGV[1],ARGV[2],ARGV[3], ARGV[4], ARGV[5]]
content = <<EOF
From: #{from}
To: #{to}
MIME-Version: 1.0
Content-type: text/html
subject: #{subject}
Date: #{Time.now.rfc2822}

<h3>Get Satisfaction Top 5 active:</h3>
<p>
#{reverse_sorted[0]['numReplies']},<a href=\"#{reverse_sorted[0]['topic_url']}\">#{reverse_sorted[0]['topic_url']}</a><br />
#{reverse_sorted[1]['numReplies']},<a href=\"#{reverse_sorted[1]['topic_url']}\">#{reverse_sorted[1]['topic_url']}</a><br />
#{reverse_sorted[2]['numReplies']},<a href=\"#{reverse_sorted[2]['topic_url']}\">#{reverse_sorted[2]['topic_url']}</a><br />
#{reverse_sorted[3]['numReplies']},<a href=\"#{reverse_sorted[3]['topic_url']}\">#{reverse_sorted[3]['topic_url']}</a><br />
#{reverse_sorted[4]['numReplies']},<a href=\"#{reverse_sorted[4]['topic_url']}\">#{reverse_sorted[4]['topic_url']}</a><br />
</p>
<h3>Get Satisfaction Contributors:</h3>
<p>
#{contributors}
</p>

<h3>Top 10 Get Satisfaction Repliers:</h3>
<p>
#{top_10_repliers}
</p>
<h3>5 Random Get Satisfaction Topics:</h3>
<p>#{five_random_topics}
</p>

<h3>New Topics</h3>
<p>#{topicURLs}
</p>
EOF
print 'content', content

Net::SMTP.enable_tls(OpenSSL::SSL::VERIFY_NONE)  
Net::SMTP.start('smtp.gmail.com', 587, 'gmail.com', from, p, :login) do |smtp| 
  smtp.send_message(content, from, to)
end


