#!/usr/bin/env ruby
require 'rubygems'
require 'json'
require 'pp'
require 'time'
require 'date'
require 'optparse'
require 'optparse/time'
require 'ostruct'
require 'mongo'

tags_to_search_for = []
class Optparse
  CODES = %w[iso-2022-jp shift_jis euc-jp utf8 binary]
  CODE_ALIASES = { "jis" => "iso-2022-jp", "sjis" => "shift_jis" }

  def self.parse(args)
    # The options specified on the command line will be collected in *options*.
    # We set default values here.
    options = OpenStruct.new
    options.library = []
    options.inplace = false
    options.encoding = "utf8"
    options.transfer_type = :auto
    options.verbose = false

    opts = OptionParser.new do |opts|
      opts.banner = "Usage: bruteforceSearch.rb [options]"

      opts.separator ""
      opts.separator "Specific options:"
      # List of arguments.
      opts.on("-t", "--tags x,y,z", Array, "Tags separated by commas") do |list|
        options.tags = list
      end
      opts.on("-k", "--keywords x,y,z", Array, "Keywords separated by commas") do |list|
        options.keywords = list
      end
    
      opts.separator ""
      opts.separator "Common options:"

      # No argument, shows at tail.  This will print an options summary.   
      opts.on_tail("-h", "--help", "Show this message") do
        puts opts
        exit
      end
    end # do |opts|
    opts.parse!(args)
    options
  end  # parse()
end  # class Optparse

db = Mongo::Connection.new.db("gs") # no error checking  :-) assume Get Satisfaction Database is there on localhost
topicsColl = db.collection("topics")

options = Optparse.parse(ARGV)

if ARGV.length < 6
  puts "usage: #{$0} yyyy mm dd yyyy mmm dd -t tag1,tag2,tag3...tagn -k keyword1,keyword2,keyword3,keywordn"
  exit
end

metrics_start = Time.utc(ARGV[0], ARGV[1], ARGV[2], 0, 0)
metrics_stop = Time.utc(ARGV[3], ARGV[4], ARGV[5], 23, 59)

topics = []

topicsColl.find({"last_active_at" => {"$gte" => metrics_start, "$lt" => metrics_stop}},
                  :fields => ["at_sfn", "id", "last_active_at", "fulltext", "reply_array", "tags_str"]).sort(
    [["last_active_at", Mongo::DESCENDING]]).each do |t|
  id = t["id"]
  fulltext =  t["fulltext"]
  reply_array = t["reply_array"]
  url = t["at_sfn"]
  tags_str = t["tags_str"]
  last_active_at = t["last_active_at"]
  $stderr.printf("CHECKING topic url:%s id:%d which was last active at at:%s\n",url,id,last_active_at)
  #PP::pp(reply_array, $stderr)

  options.tags.each do |tag|
    $stderr.printf("SEARCHING for tag:%s in tags_str:%s\n",tag, tags_str)
    if tags_str.include? tag.downcase 
      has_id = false 
      topics.each do |tt|
        $stderr.printf("topic id:%d is already in topics, comparing to id:%d\n",tt["id"],id)
        if tt["id"] == id
          $stderr.printf("tt[\"id\"] == id\n")
          has_id = true
          break
        end # t_id
      end # topics.each
      if !has_id
        $stderr.printf("Found tag:%s, PUSHING onto topics: id:%d, url:%s, last_active_at:%s\n", tag, id, url, last_active_at)
        topics.push({:id => id,:url => url, :last_active_at => last_active_at})
      end # has_id
      break
    end # tag_str
  end #options.tags

  options.keywords.each do |k|
    $stderr.printf("SEARCHING for keyword:%s in tags_str:%s\n", k, fulltext)
    if fulltext.include? k 
      has_id = false 
      topics.each do |tt|
        $stderr.printf("topic id:%d is already in topics, comparing to id:%d\n",tt["id"],id)
        if tt["id"] == id
          $stderr.printf("tt[\"id\"] == id\n")
          has_id = true
          break
        end # t_id
      end # topics.each
      if !has_id
        $stderr.printf("Found keyword:%s, PUSHING onto topics: id:%d, url:%s, last_active_at:%s\n", k, id, url, last_active_at)
        topics.push({:id => id,:url => url, :last_active_at => last_active_at})
      end # has_id
      break
    end # tag_str
  end #options.tags

end #topicsColl.find

topics = topics.sort_by{|c|c[:id]}

topics.reverse.each do |t|
  PP::pp(t, $stderr)
  printf("url: %s id: %d last_active_at:%s\n",t[:url], t[:id], t[:last_active_at])
end

