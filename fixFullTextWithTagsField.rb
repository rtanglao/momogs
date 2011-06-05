#!/usr/bin/env ruby
require 'rubygems'
require 'json'
require 'pp'
require 'time'
require 'date'
require 'mongo'

db = Mongo::Connection.new.db("gs") # no error checking  :-) assume Get Satisfaction Database is there on localhost
topicsColl = db.collection("topics")

topicsColl.find().each do |t|

  if t["fulltext"].length > t["fulltext_with_tags"].length
    $stderr.printf("TOPIC ID:%d, fulltext length:%d > fulltext_with_tags length:%d, therefore FIXING full_text_with_tags\n",
      t["id"],t["fulltext"].length, t["fulltext_with_tags"].length)
    $stderr.printf("OLD full text with tags:%s\n", t["fulltext_with_tags"])
    t["fulltext_with_tags"] = t["fulltext"] + " " + t["tags_str"].gsub("~"," " )
    $stderr.printf("NEW full text with tags:%s\n", t["fulltext_with_tags"])
    topicsColl.update({"id" =>t["id"]},t,{"$set" => {"fulltext_with_tags" => t["fulltext_with_tags"]}})
  else
    $stderr.printf("NOT FIXING TOPIC ID:%d\n",t["id"])
  end
end

