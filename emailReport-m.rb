#!/usr/bin/env ruby
require 'rubygems'
require 'json'
require 'net/http'
require 'pp'
require 'time'
require 'tlsmail'
require 'date'
require 'parseconfig'

metrics_start = Time.utc(ARGV[0], ARGV[1], ARGV[2], 0, 0)
metrics_stop =  Time.utc(ARGV[3], ARGV[4], ARGV[5], 23, 59)

executable_name = $0.gsub(".rb","")

start_date = ARGV[0] + ARGV[1] + ARGV[2]
start_date_str = ARGV[0] + " " + ARGV[1] + " " + ARGV[2]

end_date = ARGV[3] + ARGV[4] + ARGV[5]
end_date_str = ARGV[3] + " " + ARGV[4] + " " + ARGV[5]

active_urls_stderrfile = 'getactive.' + start_date + '.' + end_date + '.stderr'
active_urls_stdoutfile = 'getactive.' + start_date + '.' + end_date + '.stdout'
active_urls_csvfile = "getactive-m.%s%s%s.%s%s%s.csv" % [ARGV[0],ARGV[1],ARGV[2],ARGV[3],ARGV[4],ARGV[5]]
printf(STDERR, "Get Active URLs CSV:%s\n", active_urls_csvfile)
# get the active urls
`./getactive-m.rb #{start_date_str} #{end_date_str}  2>#{active_urls_stderrfile} 1>#{active_urls_stdoutfile}`
activeURLs = "<ol>"
if File::exists?(active_urls_csvfile) && File.size(active_urls_csvfile) > 0
  File.open(active_urls_csvfile, "r") do |infile|
    num_urls = 0
    while (line = infile.gets)
      if line != "\n"
        line.gsub!("\n","")
        matchdata = /([0-9]*),([\S]*)/.match(line)
        if matchdata.nil? || matchdata[1].nil? || matchdata[2].nil?
          next
        end
        url = matchdata[2]
        num_replies = matchdata[1]
        url_without_http_and_momo_bits = url.gsub("http://getsatisfaction.com/mozilla_messaging/topics/","")       
        # <li>number comma, <a href="url">url without getsat.com/momo </a></li>
        activeURLs = activeURLs + "<li>"+num_replies+",<a href=\""+ url + "\">"+url_without_http_and_momo_bits+"</a></li>"
        num_urls += 1
        if num_urls == 6
          break
        end
      end
    end
  end
end
activeURLs = activeURLs + "</ol>"

stderrfile = 'getcontributors-m.' + start_date + '.' + end_date + '.stderr'
stdoutfile = 'getcontributors-m.' + start_date + '.' + end_date + '.stdout'
csvfile = "getcontributors-m.%s%s%s.%s%s%s.csv" % [ARGV[0],ARGV[1],ARGV[2],ARGV[3],ARGV[4],ARGV[5]]
printf(STDERR, "CONTRIBUTORS CSV:%s\n", csvfile)

`./getcontributors-m.rb #{start_date_str} #{end_date_str} 2>#{stderrfile} 1>#{stdoutfile}`

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
`./gethappykludged-m.rb #{start_date_str} #{end_date_str} 2>#{gethappy_stderrfile} 1>#{gethappy_stdoutfile}`
gethappy_csv_file = "gethappykludged-m."+ARGV[0]+ARGV[1]+ARGV[2]+"."+ARGV[3]+ARGV[4]+ARGV[5] + ".csv"

top_10_repliers = `head -n 10 #{gethappy_csv_file}`
top_10_repliers.gsub!("\n","<br />")

getrandom_stderrfile = 'getrandom.' + start_date + '.' + end_date + '.stderr'
getrandom_stdoutfile = 'getrandom.' + start_date + '.' + end_date + '.stdout'
random_csvfile = "getrandom-m.%s%s%s.%s%s%s.csv" % [ARGV[0],ARGV[1],ARGV[2],ARGV[3],ARGV[4],ARGV[5]]
printf(STDERR, "RANDOM CSV:%s\n", random_csvfile)
# get 5 random topics
`./getrandom-m.rb #{start_date_str} #{end_date_str} 5 2>#{getrandom_stderrfile} 1>#{getrandom_stdoutfile}`

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
urls_csvfile = "gettopicURLs-m.%s%s%s.%s%s%s.csv" % [ARGV[0],ARGV[1],ARGV[2],ARGV[3],ARGV[4],ARGV[5]]
printf(STDERR, "TOPIC URLs CSV:%s\n", urls_csvfile)
# get the topics created today
`./gettopicURLs-m.rb #{start_date_str} #{end_date_str}  2>#{geturls_stderrfile} 1>#{geturls_stdoutfile}`
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
#{activeURLs}
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


