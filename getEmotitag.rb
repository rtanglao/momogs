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

emotitagsByMonth = []
topicsColl.find({"last_active_at" => {"$gte" => metrics_start, "$lte" => metrics_stop},
                 "reply_array" => { "$elemMatch"  => { "created_at" =>  {"$gte" => metrics_start, "$lte" => metrics_stop }}}}
                ).each do |t|
  $stderr.printf("topic:%d, reply_count:%d\n", t["id"], t["reply_count"])
  url = t["at_sfn"]
  t["reply_array"].each do |r|
    created_at = r["created_at"]
    $stderr.printf("CHECKING reply:%d by author:%s\n", r["id"],r["author"]["canonical_name"])
    if ((created_at <=> metrics_start) >= 0) && ((created_at <=> metrics_stop) <= 0)
      printf(STDERR, "START*** of reply\n")
      PP::pp(r,$stderr)
      printf(STDERR, "\nEND*** of reply\n")
      if !r.has_key?("emotitag")
        r["emotitag"]= { "face" => "emotitagMissing"}
      end
      face = r["emotitag"]["face"]
      
      $stderr.printf("IN time period, reply id:%d has face:%s\n", r["id"], face)
      yyyymm_str = created_at.year.to_s + sprintf("%0.2d",created_at.month.to_s)
      e = emotitagsByMonth.detect{|e|e[:yyyymm] == yyyymm_str}
      if e.nil? 
        $stderr.printf("emotitag:%s for:%s NOT found\n", face, yyyymm_str)
        emotitagsByMonth.push({:yyyymm => yyyymm_str, "happy" => 0, "sad" => 0,"silly" => 0,"indifferent" => 0,
          "emotitagMissing" => 0})
        e = emotitagsByMonth.last
      end
      printf(STDERR, "START*** of emotitag\n")
      PP::pp(e,$stderr)
      printf(STDERR, "\nEND*** of emotitag\n")
      $stderr.printf("INCREMENTING emotitag:%s for:%s FROM:%d TO:%d\n", face, yyyymm_str,e[face], e[face]+1)
      e[face] += 1
    else
      $stderr.printf("NOT in time period, reply:%d\n", r["id"])
    end      
  end
end
 
executable_name = $0.gsub(".rb","") 
printf(STDERR, "CSV filename:%s.%s%s%s.%s%s%s.csv",executable_name,ARGV[0],ARGV[1],ARGV[2],ARGV[3],ARGV[4],ARGV[5])
 
csv_file = File.new(executable_name+"."+ARGV[0]+ARGV[1]+ARGV[2]+"."+ARGV[3]+ARGV[4]+ARGV[5] + ".csv", "w")
csv_file.puts("yyyymm,happy,sad,silly,indifferent,emotitagMissing")

emotitagsByMonth = emotitagsByMonth.sort_by{|c|c[:yyyymm]}
emotitagsByMonth.each{|row|
  csv_file.puts "#{row[:yyyymm]},#{row["happy"]},#{row["sad"]},#{row["silly"]},#{row["indifferent"]},#{row["emotitagMissing"]}"
}
 
csv_file.close
