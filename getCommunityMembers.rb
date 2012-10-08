#!/usr/bin/env ruby
require 'rubygems'
require 'json'
require 'pp'
require 'time'
require 'date'
require 'getGSResponseTyphoeus'

# https://gist.github.com/3842641
if not defined?(Ocra)
  if ARGV.length < 1
    puts "usage: #{$0} [community]"
    exit
  end
end

community = ARGV[0]

member_page = 0
total = 1
verbose_logging = false
while total > 0
  member_page += 1
  $stderr.printf("HTTP GET page:%d of /companies/%s/people\n", member_page, community)
  members = getResponse("companies/" + community + "/people.json", 
    {:page => member_page, :limit => 30})
  members["data"].each do |member|
    printf("%s,%s\n", member["name"], member["canonical_name"])
  end
  if member_page == 1
    total = members["total"]
  else
    total -=30
  end
end # while
 
