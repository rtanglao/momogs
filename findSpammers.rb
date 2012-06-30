#!/usr/bin/env ruby -wKU
# -*- coding: utf-8 -*-
require 'rubygems'
require 'json'
require 'time'
require 'date'
require 'mongo'
require 'pp'

MONGO_HOST = ENV["MONGO_HOST"]
raise(StandardError,"Set Mongo hostname in ENV: 'MONGO_HOST'") if !MONGO_HOST
MONGO_PORT = ENV["MONGO_PORT"]
raise(StandardError,"Set Mongo port in ENV: 'MONGO_PORT'") if !MONGO_PORT
MONGO_USER = ENV["MONGO_USER"]
raise(StandardError,"Set Mongo user in ENV: 'MONGO_USER'") if !MONGO_USER
MONGO_PASSWORD = ENV["MONGO_PASSWORD"]
raise(StandardError,"Set Mongo user in ENV: 'MONGO_PASSWORD'") if !MONGO_PASSWORD
db = Mongo::Connection.new(MONGO_HOST, MONGO_PORT.to_i).db("gs")
auth = db.authenticate(MONGO_USER, MONGO_PASSWORD)
if !auth
  raise(StandardError, "Couldn't authenticate, exiting")
  exit
end
print "connected\n"
topicsColl = db.collection("topics")
t = topicsColl.find({"subject" => /[êửáạướáĐôảôệ]/u}).count()
print "after find\n"
if t == nil
  printf("t is nil\n")
end
printf("t:%d\n", t)
# pp t["subject"]
