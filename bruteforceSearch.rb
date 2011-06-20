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

topics = []

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
      opts.on("-t", "--tags x,y,z", Array, "Tags separated by commas (each tag will be ORed)") do |list|
        options.tags = list
      end
      opts.on("-k", "--keywords x,y,z", Array, "Keywords separated by commas (each keyword will be ORed)") do |list|
        options.keywords = list
      end
      opts.on("-u", "--atags x,y,z", Array, "Tags separated by commas (each tag will be ANDed)") do |list|
        options.atags = list
      end
      opts.on("-l", "--akeywords x,y,z", Array, "Keywords separated by commas (each keyword will be ANDed)") do |list|
        options.akeywords = list
      end
      opts.on("-r", "--fregex x,y,z", Array, "regexes for fulltext separated by commas (each regex will be ORed)") do |list|
        options.fregexes = list
      end
      opts.on("-s", "--tregex x,y,z", Array, "regexes for tags separated by commas (each regex will be ORed)") do |list|
        options.tregexes = list
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

def add_to_topics_array_if_missing(topics, id, url, last_active_at)
  if !(topics.any? {|tt|tt[:id] == id})
    topics.push({:id => id,:url => url, :last_active_at => last_active_at})
  end
end

def remove_from_topics_array_if_present(topics, id)
  topics.delete_if{|tt|tt[:id] == id}
end

db = Mongo::Connection.new.db("gs") # no error checking  :-) assume Get Satisfaction Database is there on localhost
topicsColl = db.collection("topics")

options = Optparse.parse(ARGV)

if ARGV.length < 6
  puts "usage: #{$0} yyyy mm dd yyyy mmm dd -t tag1,tag2,tag3...tagn -k keyword1,keyword2,keyword3,keywordn -r regexforfulltext1,rgexforfulltext2 -s regexfortags1,regexfortags2"
  exit
end

metrics_start = Time.utc(ARGV[0], ARGV[1], ARGV[2], 0, 0)
metrics_stop = Time.utc(ARGV[3], ARGV[4], ARGV[5], 23, 59)


topicsColl.find({"last_active_at" => {"$gte" => metrics_start, "$lt" => metrics_stop}},
                  :fields => ["at_sfn", "id", "last_active_at", "fulltext", "reply_array", "tags_str"]).sort(
    [["last_active_at", Mongo::DESCENDING]]).each do |t|
  id = t["id"].to_i
  fulltext =  t["fulltext"]
  reply_array = t["reply_array"]
  url = t["at_sfn"]
  tags_str = t["tags_str"]
  last_active_at = t["last_active_at"]
  $stderr.printf("CHECKING topic url:%s id:%d which was last active at at:%s\n",url,id,last_active_at)

  boolean_or_match = false
  matched_keyword = nil
  matched_tag = nil
  matched_regex = nil

  if !options.tags.nil?
    matched_tag = options.tags.detect {|tag|tags_str.include? tag.downcase}
    if matched_tag
      boolean_or_match = true
    end
  end

  if !boolean_or_match && !options.keywords.nil?
    matched_keyword = options.keywords.detect {|k|fulltext.include? k.downcase}
  end

  if !matched_keyword.nil?
    boolean_or_match = true
  end

  if !boolean_or_match && !options.fregexes.nil?
    regexes = options.fregexes.collect {|re_str|%r|#{re_str}|}
    matched_regex = regexes.detect {|re|re.match fulltext}
  end

  if !matched_regex.nil?
    boolean_or_match = true
  end
  
  if !boolean_or_match && !options.tregexes.nil?
    regexes = options.tregexes.collect {|re_str|%r|#{re_str}|}
    matched_regex = regexes.detect {|re|re.match tags_str}
  end

  if !matched_regex.nil?
    boolean_or_match = true
  end
  
  if !boolean_or_match
    next
  end

  add_to_topics_array_if_missing(topics, id, url, last_active_at)

  if !options.atags.nil?
    $stderr.printf("options.atags is NOT nil\n")
    if !options.atags.all? {|tag|tags_str.include? tag.downcase}
      $stderr.printf("ATAGS; removing id:%d\n", id)
      remove_from_topics_array_if_present(topics, id)
      next
    end
  end

  if !options.akeywords.nil?
    if !options.akeywords.all? {|k|fulltext.include? k.downcase}
      $stderr.printf("AKEYWORDS; removing id:%d\n", id)
      remove_from_topics_array_if_present(topics, id)
    end
  end

end #topicsColl.find

topics = topics.sort_by{|c|c[:last_active_at]}

topics.reverse.each do |t|
  PP::pp(t, $stderr)
  printf("url: %s id: %d last_active_at:%s\n",t[:url], t[:id], t[:last_active_at])
end

