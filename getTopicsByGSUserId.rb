#!/usr/bin/env ruby
require 'rubygems'
require 'json'
require 'time'
require 'date'
require 'mongo'

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

if ARGV.length < 1
  puts "usage: #{$0} [userid for topics]"
  exit
end

userid = ARGV[0]

topicsColl.find({"author.canonical_name" => userid},
                :fields => ["at_sfn", "id", "subject", "content", "author"]
                ).each do |t|
  printf("URL:%s TITLE:%s,FIRST66:%s\n", t["at_sfn"],t["subject"], t["content"][0..66])
end
