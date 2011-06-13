#!/usr/bin/env ruby
require 'rubygems'
require 'json'
require 'pp'
require 'date'
require 'time'
require 'mongo'
 
if ARGV.length < 6
  puts "usage: #{$0} yyyy mm dd yyyy mmm dd"
  exit
end
 
metrics_start = Time.utc(ARGV[0], ARGV[1], ARGV[2], 0, 0)
metrics_stop = Time.utc(ARGV[3], ARGV[4], ARGV[5], 23, 59)

db = Mongo::Connection.new.db("gs") # no error checking  :-) assume Get Satisfaction Database is there on localhost
topicsColl = db.collection("topics")

contributors = []
topicsColl.find({"last_active_at" => {"$gte" => metrics_start, "$lte" => metrics_stop},
                 "reply_array" => { "$elemMatch"  => { "created_at" =>  {"$gte" => metrics_start, "$lte" => metrics_stop }}}}
                ).each do |t|
  $stderr.printf("topic:%d, reply_count:%d\n", t["id"], t["reply_count"])
  url = t["at_sfn"]
  t["reply_array"].each do |r|
    created_at = r["created_at"]
    $stderr.printf("CHECKING reply:%d by author:%s\n", r["id"],r["author"]["canonical_name"])
    if ((created_at <=> metrics_start) >= 0) && ((created_at <=> metrics_stop) <= 0)
      author = r["author"]["canonical_name"]
      $stderr.printf("IN time period, author:%s has a reply id:%d\n", author, r["id"])
      author_found = false
      contributors.each do |c|
        $stderr.printf("contributor loop:author:%s\n",c[:author])
        if c[:author] == author
          $stderr.printf("FOUND author:%s! Incrementing num_replies:%d\n", author,c[:num_replies]) 
          c[:num_replies] += 1
          author_found = true
          break
        end
      end # contributors
      if !author_found
        $stderr.printf("DID NOT FIND author:%s! Adding Author, setting num_replies to 1\n", author) 
        contributors.push({:author => author,:num_replies => 1})
      end
    else
      $stderr.printf("NOT in time period, reply:%d\n", r["id"])
    end      
  end
end
 
executable_name = $0.gsub(".rb","") 
printf(STDERR, "CSV filename:%s.%s%s%s.%s%s%s.csv",executable_name,ARGV[0],ARGV[1],ARGV[2],ARGV[3],ARGV[4],ARGV[5])
 
csv_file = File.new(executable_name+"."+ARGV[0]+ARGV[1]+ARGV[2]+"."+ARGV[3]+ARGV[4]+ARGV[5] + ".csv", "w")

contributors = contributors.sort_by{|c|c[:num_replies]}
contributors.reverse.each{|row|
  csv_file.puts "#{row[:num_replies]},#{row[:author]}"
}
 
csv_file.close
