#!/usr/bin/env ruby
require 'rubygems'
require 'json'
require 'pp'
require 'time'
require 'date'
require 'mongo'
require 'date'
require 'parseconfig'

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

if ARGV.length < 2
  puts "usage: #{$0} yyyy mm"
  exit
end

yyyy = ARGV[0].to_i
mm = ARGV[1].to_i
# compute start and stop times and 3 letter month name e.g. Feb for each of the last 12 months and store in array
# each array element has: metrics_start, metrics_stop, month name, number of topics created, number of topics marked complete in that time period
kpi_percentage_complete_last_twelve_months = []

12.times do
  next_yyyy = yyyy
  next_mm = mm + 1
  previous_yyyy = yyyy
  previous_mm = mm - 1

  if mm == 12 
    next_mm = 1
    next_yyyy += 1 
  end

  if mm == 1 
    previous_mm = 12
    previous_yyyy = yyyy - 1
  end

  kpi_percentage_complete_last_twelve_months.push(
  {
    "metrics_start" => Time.utc(yyyy, mm, 1, 0, 0),
    "metrics_stop"  => Time.utc(next_yyyy, next_mm, 1, 0, 0),
    "three_letter_month_name" => Time.utc(yyyy, mm, 1, 0, 0).strftime("%b"),
    "num_topics_created" => 0,
    "num_topics_completed" => 0,
    "percentage_completed" => 0.0
   })
   mm = previous_mm
   yyyy = previous_yyyy  
end

# loop through array and then compute number of topics created_at versus status_journal status "complete" to get % Solved
# and then output CSV File of the form: Month, % e.g. Feb,24.3 or Jan,21.6
csv_percentage_complete = []

# Compute Num Topics Created in the Last 12 months
kpi_percentage_complete_last_twelve_months.each do |k_complete|
  k_complete["num_topics_created"] = topicsColl.find({"created_at" => 
                    {"$gte" => k_complete["metrics_start"], "$lt" => k_complete["metrics_stop"]}}).count()
end

# Compute Num Topics Completed in the Last 12 months and Percentage Completed
kpi_percentage_complete_last_twelve_months.each do |k_complete|
  metrics_start = k_complete["metrics_start"]
  metrics_stop = k_complete["metrics_stop"]
  topicsColl.find({"last_active_at" => {"$gte" => metrics_start, "$lt" => metrics_stop},
                  "status" => "complete"},
                  :fields => ["last_active_at", "at_sfn", "id", "subject", "synthetic_status_journal","author"]).each do |t|
    $stderr.printf("***START of topic\n")
    PP::pp(t,$stderr)
    $stderr.printf("***END of topic\n")
    # A topic is answered in the time period if and only if:
    # the first status_update_time to be "complete" is within in the time period
    # SMALL BUG: this fails if MongoDB was updated more than a day AFTER the topic was marked solved in Get Satisfaction 
    # LUCKILY this only happens with very old solved topics and is therefore rare
    sj = t["synthetic_status_journal"].detect {|status_journal|status_journal["status"] == "complete" }
    if sj && (sj["status_update_time"] <=> metrics_start) >= 0 && 
         (sj["status_update_time"] <=> metrics_stop) == -1
      $stderr.printf("SOLVED topic in time period title:%s url:%s\n",t["subject"].gsub(","," - ")[0..79],t["at_sfn"])
      k_complete["num_topics_completed"] += 1
    end
  end
  k_complete["percentage_completed"] = 100.0 * k_complete["num_topics_completed"] / k_complete["num_topics_created"]
  $stderr.printf("PERCENTAGE:%f, completed:%d, complete:%d\n", k_complete["percentage_completed"],
    k_complete["num_topics_completed"], k_complete["num_topics_created"])
  csv_percentage_complete.push({"three_letter_month_name"=>k_complete["three_letter_month_name"],
                                 "percentage_completed" => k_complete["percentage_completed"]})
end

csv_percentage_complete.reverse.each do |c| 
  printf "%s,%f\n", c["three_letter_month_name"], c["percentage_completed"]
end

