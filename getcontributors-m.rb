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

updated_topics = []
contributors = []
topicsColl.find({"last_active_at" => {"$gte" => metrics_start, "$lte" => metrics_stop},
                 "reply_array" => { "$elemMatch"  => { "created_at" =>  {"$gte" => metrics_start, "$lte" => metrics_stop }}}}
                ).each do |t|
  $stderr.printf("topic:%d, reply_count:%d\n", t["id"], t["reply_count"])
  url = t["at_sfn"]
  t["reply_array"].each do |r|
    created_at = r["created_at"]
    star_promoted = r["star_promoted"]
    company_promoted = r["company_promoted"]
    $stderr.printf("CHECKING reply:%d company_promoted:%s, star_promoted:%s\n", r["id"], company_promoted, star_promoted)
    if ((created_at <=> metrics_start) >= 0) && ((created_at <=> metrics_stop) <= 0)
      author = r["author"]["canonical_name"]
      if star_promoted || company_promoted
        $stderr.printf("In time period, %s has a company promoted or star promoted reply id:%d\n", author, r["id"])
        contributor_found = false
        contributors.each do |c|
          $stderr.printf("contributor loop:author:%s\n",c[:author])
          if c[:author] == author
            c[:num_promoted_or_starred] += 1
            contributor_found = true
            break
          end
        end #contributors.each
        if !contributor_found
          contributors.push({:author => author,:num_promoted__or_starred => 1})
        end
      else
        $stderr.printf("In time period, reply:%d NOT company promoted or star promoted; company:%s, star:%s\n", 
          r["id"], company_promoted, star_promoted)
      end  
    end  
  end
end
 
executable_name = $0.gsub(".rb","") 
printf(STDERR, "CSV filename:%s.%s%s%s.%s%s%s.csv",executable_name,ARGV[0],ARGV[1],ARGV[2],ARGV[3],ARGV[4],ARGV[5])
 
csv_file = File.new(executable_name+"."+ARGV[0]+ARGV[1]+ARGV[2]+"."+ARGV[3]+ARGV[4]+ARGV[5] + ".csv", "w")

contributors = contributors.sort_by{|c|c[:num_promoted_or_starred]}
contributors.reverse.each{|row|
  csv_file.puts "#{row[:num_promoted_or_starred]},#{row[:author]}"
}
 
csv_file.close
