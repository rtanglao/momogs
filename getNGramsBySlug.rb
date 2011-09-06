#!/usr/bin/env ruby
require 'rubygems'
require 'json'
require 'net/http'
require 'pp'
require 'time'
require 'date'
require 'mongo'
require 'sanitize'
require 'awesome_print'

def get2And3Grams(text)
  bi_grams = Hash.new(0)
  tri_grams = Hash.new(0)
  words = Sanitize.clean(text).downcase.scan(/\w+/)
  num = words.length - 2

  num.times {|i|
    bi = words[i] + ' ' + words[i+1]
    tri = bi + ' ' + words[i+2]
    bi_grams[bi] += 1
    tri_grams[tri] += 1
  }

  bb = bi_grams.sort{|a,b| b[1] <=> a[1]}
# (num / 10).times {|i|  puts "#{bb[i][0]} : #{bb[i][1]}"}

  tt = tri_grams.sort{|a,b| b[1] <=> a[1]}
# (num / 10).times {|i|  puts "#{tt[i][0]} : #{tt[i][1]}"}

  return bb, tt
end

if ARGV.length < 1
  puts "usage: #{$0} slug"
  exit
end

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

slug = ARGV[0]

existing_topic =  topicsColl.find_one({"slug" =>slug},  :fields => ["subject", "content","id"])

if existing_topic
  PP::pp(existing_topic, $stderr)

  bigrams, trigrams = get2And3Grams(existing_topic["subject"] + " " + existing_topic["content"])

  ap bigrams, :indent => -2
  ap trigrams, :indent => -2

else
  $stderr.printf("Slug:%s NOT FOUND, EXITING!\n",slug)
end
