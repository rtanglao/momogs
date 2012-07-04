#!/usr/bin/env ruby
require 'rubygems'
require 'json'
require 'pp'
require 'time'
require 'date'
require 'mongo'
require 'typhoeus'
require 'parseconfig'
mongohq_config = ParseConfig.new('mongohq.conf').params
apikey = mongohq_config['apikey']
result = Typhoeus::Request.get("https://api.mongohq.com/databases/gs/collections/topics/documents",
  :headers => {'Content-Type' => "application/json"},
  :params => { "_apikey" => apikey, "limit" => 1,
   "q" => 
     "{\"at_sfn\" : \"http://getsatisfaction.com/mozilla_messaging/topics/i_lost_emails\"}"
})
parsed =  JSON.parse(result.body)
pp parsed[0]["slug"]

